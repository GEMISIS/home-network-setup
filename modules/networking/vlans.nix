{ config, lib, ... }:

with lib;

let
  cfg = config.router.networking.vlans;
  hw  = config.router.hw;
  vl  = config.router.vlans;
  addr4 = config.router.addr4.base;

  mkIPv4 = vid:
    let
      cidr  = addr4."${toString vid}";
      parts = splitString "/" cidr;
    in {
      address = elemAt parts 0;
      prefixLength = toInt (elemAt parts 1);
    };

  trunkVids  = [ vl.iot vl.autom vl.guest vl.home vl.media vl.ha ];
  camerasVid = vl.cams;
  mgmtVid    = vl.mgmt;

  vlanAttrs = listToAttrs (
    map
      (vid: {
        name = "${hw.trunk.iface}.${toString vid}";
        value = { interface = hw.trunk.iface; id = vid; };
      })
      trunkVids
    ++ [
      {
        name = "${hw.cameras.iface}.${toString camerasVid}";
        value = { interface = hw.cameras.iface; id = camerasVid; };
      }
    ]
  );

  ifaceAttrs = listToAttrs (
    map
      (vid:
        let
          ifName = "${hw.trunk.iface}.${toString vid}";
        in {
          name = ifName;
          value = { ipv4.addresses = [ (mkIPv4 vid) ]; useDHCP = false; };
        }
      )
      trunkVids
    ++ [
        (let
          ifName = "${hw.cameras.iface}.${toString camerasVid}";
        in {
          name = ifName;
          value = { ipv4.addresses = [ (mkIPv4 camerasVid) ]; useDHCP = false; };
        })
        {
          name = hw.mgmt.iface;
          value = { ipv4.addresses = [ (mkIPv4 mgmtVid) ]; useDHCP = false; };
        }
      ]
  );
in
{
  options.router.networking.vlans.enable = mkOption {
    type = types.bool;
    default = false;
    description = "Enable VLAN subinterfaces and addressing.";
  };

  config = mkIf cfg.enable {
    networking = {
      useNetworkd = true;
      useDHCP = false;
      networkmanager.enable = false;
      dhcpcd.enable = false;
      vlans = vlanAttrs;
      interfaces = ifaceAttrs;
    };
    systemd.network.enable = true;
    systemd.network.wait-online.enable = true;
  };
}

