{ config
, lib
, ...
}:
with lib; let
  cfg = config.router.networking.firewallBase;
  mgmtIface = config.router.hw.mgmt.iface;
  vl = config.router.vlans;
  hw = config.router.hw;
  trunkVids = [ vl.iot vl.autom vl.guest vl.home vl.media vl.ha ];
  vlanIfaces =
    (map (v: "${hw.trunk.iface}.${toString v}") trunkVids)
    ++ [ "${hw.cameras.iface}.${toString vl.cams}" mgmtIface ];
  udpIfaceAttrs = listToAttrs (map
    (iface: {
      name = iface;
      value = { allowedUDPPorts = [ 67 68 ]; };
    })
    vlanIfaces);
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
      interfaces =
        udpIfaceAttrs
        // {
          "${mgmtIface}".allowedTCPPorts = [ 22 ];
          lo.allowedTCPPorts = [ 22 ];
        };
    };
  };
}
