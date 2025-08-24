{ config, lib, ... }:

with lib;

let
  cfg = config.router.ops.updates;
in {
  options.router.ops.updates = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic NixOS upgrades.";
    };
  };

  config = mkIf cfg.enable {
    services.nixos-upgrade = {
      enable = true;
      timerConfig.OnCalendar = "03:30";
    };

    users.motd = "Rollback: sudo nixos-rebuild switch --rollback\n";
  };
}

