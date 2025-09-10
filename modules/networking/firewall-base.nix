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
      "${hw.cameras.iface}.${toString vl.cams}"
      hw.mgmt.iface
    ];
  mgmtIface = hw.mgmt.iface;
  homeIface = "${hw.trunk.iface}.${toString vl.home}";
  defaultIface = {
    allowedUDPPorts = [ 53 67 68 5353 ];
    allowedTCPPorts = [ 53 ];
  };
  ifaceRules = genAttrs vlanIfaces (iface:
    if iface == mgmtIface then
      defaultIface // { allowedTCPPorts = defaultIface.allowedTCPPorts ++ [ 22 443 3100 ]; }
    else if iface == homeIface then
      defaultIface // { allowedTCPPorts = defaultIface.allowedTCPPorts ++ [ 22 443 ]; }
    else
      defaultIface
  );
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
      interfaces = ifaceRules;
    };
  };
}
