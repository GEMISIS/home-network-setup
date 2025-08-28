{ config
, lib
, ...
}:
with lib; let
  cfg = config.router.networking.firewallBase;
  vl = config.router.vlans;
  hw = config.router.hw;
  trunkVids = [ vl.iot vl.autom vl.guest vl.home vl.ha ];
  vlanIfaces =
    (map (v: "${hw.trunk.iface}.${toString v}") trunkVids)
    ++ [
      hw.trunk.iface
      hw.cameras.iface
      hw.mgmt.iface
    ];
  homeIface = "${hw.trunk.iface}.${toString vl.home}";
  adminPorts = config.router.networking.policies.mgmtAdminPorts;
  baseIfaceOpts = {
    allowedUDPPorts = [ 53 67 68 ];
    allowedTCPPorts = [ 53 ];
  };
  ifaceOpts = iface: baseIfaceOpts //
    (if elem iface [ homeIface hw.mgmt.iface ] then { allowedTCPPorts = baseIfaceOpts.allowedTCPPorts ++ adminPorts; } else {});
in
{
  options.router.networking.firewallBase.enable = mkOption {
    type = types.bool;
    default = true;
    description = "Enable base nftables firewall rules.";
  };

  config = mkIf cfg.enable {
    # Keep SSH closed globally; configs/services.nix sets this open by default.
    services.openssh.openFirewall = false;

    networking.nftables.enable = true;

    networking.firewall = {
      enable = true;
      rejectPackets = false;
      interfaces = genAttrs vlanIfaces ifaceOpts;
    };
  };
}
