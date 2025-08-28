{ config, lib, ... }:

with lib;

let
  cfg = config.router;
  ifaces = [
    cfg.hw.wan.iface
    cfg.hw.trunk.iface
    cfg.hw.mgmt.iface
    cfg.hw.cameras.iface
  ];
in {
  options.router.hw = {
    wan.iface     = mkOption { type = types.str; };
    trunk.iface   = mkOption { type = types.str; };
    mgmt.iface    = mkOption { type = types.str; };
    cameras.iface = mkOption { type = types.str; };
  };

  options.router.vlans = {
    iot   = mkOption { type = types.int; default = 10; };
    autom = mkOption { type = types.int; default = 20; };
    guest = mkOption { type = types.int; default = 30; };
    home  = mkOption { type = types.int; default = 40; };
    media = mkOption { type = types.int; default = 50; };
    ha    = mkOption { type = types.int; default = 51; };
    cams  = mkOption { type = types.int; default = 60; };
    mgmt  = mkOption { type = types.int; default = 70; };
  };

  options.router.addr4.base = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        address = mkOption { type = types.str; };
        prefixLength = mkOption { type = types.int; };
      };
    });
    default = {
      "10" = { address = "192.168.10.1"; prefixLength = 24; };
      "20" = { address = "192.168.20.1"; prefixLength = 24; };
      "30" = { address = "192.168.30.1"; prefixLength = 24; };
      "40" = { address = "192.168.40.1"; prefixLength = 24; };
      "50" = { address = "192.168.50.1"; prefixLength = 24; };
      "51" = { address = "192.168.51.1"; prefixLength = 24; };
      "60" = { address = "192.168.60.1"; prefixLength = 24; };
      "70" = { address = "192.168.70.1"; prefixLength = 24; };
    };
  };

  config.assertions = [
    {
      assertion = all (iface: iface != "") ifaces && (length (unique ifaces) == length ifaces);
      message = "All router interfaces must be non-empty and distinct.";
    }
    {
      assertion = cfg.vlans.cams == 60;
      message = "Cameras use VLAN 60 tagged; no untagged IP on the camera interface.";
    }
  ];
}

