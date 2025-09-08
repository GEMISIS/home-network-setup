{ config, lib, ... }:

with lib;

let
  cfg = config.router.networking.nat;
  vlans = config.router.vlans;
  hw = config.router.hw;

  # VLANs carried over the trunk interface that require NAT
  trunkVids = [ vlans.iot vlans.guest vlans.home vlans.media ];
  trunkIfaces = map (v: if v == vlans.media then hw.trunk.iface else "${hw.trunk.iface}.${toString v}") trunkVids;

  # Include the dedicated management interface as a NAT source as well
  natInterfaces = trunkIfaces ++ [ hw.mgmt.iface ];
in {
  options.router.networking.nat = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    wanInterface = mkOption {
      type = types.str;
      default = config.router.hw.wan.iface;
    };
    useDhcpOnWan = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      networking.nat = {
        enable = true;
        enableIPv6 = false; # placeholder for future IPv6 PD
        externalInterface = cfg.wanInterface;
        internalInterfaces = natInterfaces;
      };
    }
    (mkIf cfg.useDhcpOnWan {
      networking.interfaces."${cfg.wanInterface}".useDHCP = true;
    })
  ]);
}

