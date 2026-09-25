{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.router.ops.diskSafety;

  diskGuard = pkgs.writeShellScript "disk-guard" ''
    set -u
    pct=$(df --output=pcent / | tail -1 | tr -dc 0-9)
    # btrfs can ENOSPC with df showing free space once every chunk is
    # allocated, so watch unallocated space too.
    unalloc=$(btrfs filesystem usage -b / | awk '/Device unallocated:/ {print $3}')
    unalloc_gib=$(( unalloc / 1024 / 1024 / 1024 ))

    if [ "$unalloc_gib" -lt ${toString cfg.minUnallocatedGiB} ]; then
      echo "<3>disk-guard: only ''${unalloc_gib} GiB btrfs unallocated - rebalancing"
      btrfs balance start -dusage=20 /
    fi

    if [ "$pct" -ge ${toString cfg.emergencyPercent} ]; then
      echo "<2>disk-guard: / is at ''${pct}% - running emergency cleanup"
      # Truncate rather than delete: deleting a file a daemon still has open
      # frees nothing until it restarts.
      find /var/log/unifi -type f -size +100M -print -exec truncate -s 0 {} +
      journalctl --vacuum-size=200M
      # Only unreferenced store paths; keeps every system generation.
      ${config.nix.package}/bin/nix-collect-garbage
      echo "<4>disk-guard: / now at $(df --output=pcent / | tail -1 | tr -d ' ')"
    elif [ "$pct" -ge ${toString cfg.warnPercent} ]; then
      echo "<3>disk-guard: / is at ''${pct}% (warn threshold ${toString cfg.warnPercent}%)"
    fi
  '';
in {
  options.router.ops.diskSafety = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Keep the root filesystem from ever filling up.

        Motivation: on 2026-09-24 an unbounded UniFi mongod.log filled the
        btrfs root. A power loss in that state left /etc/shadow missing and
        /etc/passwd, /etc/group and the UniFi database truncated, which
        locked out every login and took networking down on the next boot.
      '';
    };

    warnPercent = mkOption {
      type = types.int;
      default = 85;
      description = "Root usage (%) at which disk-guard logs an error.";
    };

    minUnallocatedGiB = mkOption {
      type = types.int;
      default = 5;
      description = "Below this much btrfs unallocated space, disk-guard runs a light balance.";
    };

    emergencyPercent = mkOption {
      type = types.int;
      default = 92;
      description = "Root usage (%) at which disk-guard truncates logs and runs GC.";
    };
  };

  config = mkIf cfg.enable {
    # UniFi rotates its own server/access logs, but not mongod.log (the one
    # that filled the disk). logrotate runs hourly; size overrides frequency.
    services.logrotate = {
      enable = true;
      settings."/var/log/unifi/mongod.log" = {
        su = "unifi unifi";
        size = "50M";
        rotate = 3;
        compress = true;
        copytruncate = true;
        missingok = true;
        notifempty = true;
      };
    };

    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        # Long enough to keep manually tested update generations for rollback.
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
      settings = {
        # During builds, GC until 20 GiB free whenever free space drops below 5 GiB.
        min-free = 5 * 1024 * 1024 * 1024;
        max-free = 20 * 1024 * 1024 * 1024;
      };
    };

    services.btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = [ "/" ];
    };

    # Compact partly-empty chunks back into unallocated space so metadata can
    # always grow (on 2026-09-25 only 3 GiB was left unallocated).
    systemd.services.btrfs-balance = {
      description = "Light btrfs balance of /";
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        ExecStart = "${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=50 -musage=50 /";
      };
    };

    systemd.timers.btrfs-balance = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Check `journalctl -t disk-guard -u disk-guard` for warnings.
    systemd.services.disk-guard = {
      description = "Warn on, and recover from, a nearly full root filesystem";
      path = [ pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.btrfs-progs config.systemd.package ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = diskGuard;
      };
    };

    systemd.timers.disk-guard = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "10min";
      };
    };
  };
}
