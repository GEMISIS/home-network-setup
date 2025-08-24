{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.router.networking.firewallBase;
  mgmtIface = config.router.hw.mgmt.iface;
in {
  options.router.networking.firewallBase.enable = mkOption {
    type = types.bool;
    default = true;
    description = "Enable base nftables firewall rules.";
  };

  config = mkIf cfg.enable {
    services.openssh.openFirewall = false;

    networking.firewall = {
      enable = true;
      backend = "nftables";
      rejectPackets = false;
      interfaces = {
        "${mgmtIface}".allowedTCPPorts = [22];
        lo.allowedTCPPorts = [22];
      };
    };
  };
}
