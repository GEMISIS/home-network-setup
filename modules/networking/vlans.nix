{ config, lib, ... }:

with lib;

let
  cfg = config.router.networking.vlans;
  hw = config.router.hw;
  vlans = config.router.vlans;
  addr4 = config.router.addr4.base;

  parseAddr = ip:
    let parts = splitString "/" ip; in {
      address = elemAt parts 0;
      prefixLength = toInt (elemAt parts 1);
    };

  trunkVids = [ vlans.iot vlans.autom vlans.guest vlans.home vlans.media vlans.ha ];

  vlanAttrs = listToAttrs (
    map
      (vid: {
        name = "${hw.trunk.iface}.${toString vid}";
        value = { interface = hw.trunk.iface; id = vid; };
      })
      trunkVids
    ++ [
      {
        name = "${hw.cameras.iface}.${toString vlans.cams}";
        value = { interface = hw.cameras.iface; id = vlans.cams; };
      }
    ]
  );

  ifaceAttrs = listToAttrs (
    map
      (vid:
        let
          ifName = "${hw.trunk.iface}.${toString vid}";
          ip = addr4."${toString vid}";
        in
        {
          name = ifName;
          value = { ipv4.addresses = [ parseAddr ip ]; };
        }
      )
      trunkVids
    ++ [
      let ifName = "${hw.cameras.iface}.${toString vlans.cams}";
      ip = addr4."60";
      in {
      name = ifName;
      value = { ipv4.addresses = [ parseAddr ip ]; };
    },
      {
        name = hw.mgmt.iface;
        value = { ipv4.addresses = [ parseAddr addr4."70" ]; };
      }
    ]
  );
in
{
  imports = [ ./vars.nix ];

  options.router.networking.vlans.enable = mkOption {
    type = types.bool;
    default = false;
    description = "Enable VLAN subinterfaces and addressing.";
  };

  config = mkIf cfg.enable {
    networking = {
      vlans = vlanAttrs;
      interfaces = ifaceAttrs;
    };
  };
}

