{ config, lib, ... }:

with lib;

let
  cfg = config.router.networking.vlans;
  hw  = config.router.hw;
  vl  = config.router.vlans;
  addr4 = config.router.addr4.base;

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
    ++ [
      {
        name = "${hw.cameras.iface}.${toString camerasVid}";
        value = { interface = hw.cameras.iface; id = camerasVid; };
      }
    ]
  );

  ifaceAttrs = listToAttrs (
    [
      { name = hw.trunk.iface;   value = { ipv4.addresses = [ addr4.${toString nativeVid} ]; useDHCP = false; }; }
      { name = hw.cameras.iface; value = { useDHCP = false; }; }
    ]
    ++ map
      (vid:
        let
          ifName = "${hw.trunk.iface}.${toString vid}";
        in {
          name = ifName;
          value = { ipv4.addresses = [ addr4.${toString vid} ]; useDHCP = false; };
        }
      )
      trunkVids
    ++ [
        (let
          ifName = "${hw.cameras.iface}.${toString camerasVid}";
        in {
          name = ifName;
          value = { ipv4.addresses = [ addr4.${toString camerasVid} ]; useDHCP = false; };
        })
        {
          name = hw.mgmt.iface;
          value = { ipv4.addresses = [ addr4.${toString mgmtVid} ]; useDHCP = false; };
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
    systemd.network = {
      enable = true;
      wait-online = {
        enable = true;
        anyInterface = true;
      };
    };
    assertions = [
      {
        assertion = config.router.services.dnsmasq.enable;
        message = "dnsmasq must be enabled to provide DHCP on VLAN interfaces.";
      }
    ];
  };
}

