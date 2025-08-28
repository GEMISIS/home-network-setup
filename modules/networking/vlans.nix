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

  trunkVids  = [ vl.iot vl.autom vl.guest vl.home vl.ha ];
  nativeVid  = vl.media;
  camerasVid = vl.cams;
  mgmtVid    = vl.mgmt;

  vlanAttrs = listToAttrs (
    map
      (vid: {
        name = "${hw.trunk.iface}.${toString vid}";
        value = { interface = hw.trunk.iface; id = vid; };
      })
      trunkVids
  );

  ifaceAttrs = listToAttrs (
    [
      { name = hw.trunk.iface;   value = { ipv4.addresses = [ (mkIPv4 nativeVid) ]; useDHCP = false; }; }
      { name = hw.cameras.iface; value = { ipv4.addresses = [ (mkIPv4 camerasVid) ]; useDHCP = false; }; }
    ]
    ++ map
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
    assertions = [
      {
        assertion = config.router.services.dnsmasq.enable;
        message = "dnsmasq must be enabled to provide DHCP on VLAN interfaces.";
      }
    ];
  };
}

