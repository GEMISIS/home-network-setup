{ config, lib, ... }:

with lib;

let
  cfg = config.router.ops.resilience;
in {
  options.router.ops.resilience = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable crash self-healing and durable crash capture.

        Motivation: on 2026-07-16 the router hit a kernel Oops in the
        nf_conntrack garbage collector (CVE-2025-38472) and then limped for
        ~14h in a corrupted state before hard-freezing, with no second dump.
        These settings make the box reboot immediately on the next fault and
        preserve the evidence across the reboot.
      '';
    };
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl = {
      # Reboot fast on the next Oops instead of running corrupted for hours.
      "kernel.panic_on_oops" = 1;
      "kernel.panic" = 10; # reboot 10s after a panic
    };

    # Hardware watchdog (box exposes iTCO_wdt / intel_oc_wdt -> /dev/watchdog).
    # If the kernel hard-locks, systemd stops petting it and the SoC resets.
    systemd.watchdog = {
      runtimeTime = "20s";
      rebootTime = "10m";
    };

    # Remove dead conntrack helper surface (auto-loaded, unused under nftables,
    # historically buggy). This is what actually prevents helper assignment;
    # the net.netfilter.nf_conntrack_helper sysctl isn't registered on this
    # kernel, so blacklisting the modules is the mechanism.
    boot.blacklistedKernelModules = [ "nf_conntrack_ftp" "nf_nat_ftp" ];

    # Quiet the flood of TPM RNG errors by trusting CPU/bootloader entropy.
    # Does NOT touch firewall "refused connection" security logging.
    boot.kernelParams = [ "random.trust_cpu=on" "random.trust_bootloader=on" ];

    # Durable crash capture: keep the journal across reboots so
    # `journalctl -b -1 -k` shows the last boot's kernel log. Kernel oops
    # traces land in pstore (efi_pstore is already loaded) and are archived
    # by systemd-pstore.service to /var/lib/systemd/pstore/.
    services.journald.storage = "persistent";
  };
}
