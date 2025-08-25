{ config, lib, ... }:

with lib;

let
  cfg = config.router.services.dnsmasq;
  hw = config.router.hw;

  mkIP = vid: "192.168.${toString vid}";

  vlanIfaces = [
    { iface = "${hw.trunk.iface}.10"; vid = 10; }
    { iface = "${hw.trunk.iface}.20"; vid = 20; }
    { iface = "${hw.trunk.iface}.30"; vid = 30; }
    { iface = "${hw.trunk.iface}.40"; vid = 40; }
    { iface = "${hw.trunk.iface}.50"; vid = 50; }
    { iface = "${hw.trunk.iface}.51"; vid = 51; }
    { iface = "${hw.cameras.iface}.60"; vid = 60; }
    { iface = hw.mgmt.iface; vid = 70; }
  ];

  mkRange = e: "${e.iface},${mkIP e.vid}.100,${mkIP e.vid}.199,255.255.255.0,12h";
  mkOptions = e: [
    "${e.iface},option:router,${mkIP e.vid}.1"
    "${e.iface},option:dns-server,${mkIP e.vid}.1"
  ];
in {
  options.router.services.dnsmasq = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dnsmasq DHCP/DNS service.";
    };
    staticLeases = mkOption {
      type = types.listOf (types.submodule {
        options = {
          mac = mkOption { type = types.str; };
          ip = mkOption { type = types.str; };
          hostname = mkOption { type = types.str; };
        };
      });
      default = [];
      description = "List of static DHCP leases.";
    };
  };

  config = mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      settings = {
        interface   = map (e: e.iface) vlanIfaces;
        dhcp-range  = map mkRange vlanIfaces;
        dhcp-option = concatMap mkOptions vlanIfaces;
        dhcp-host   = map (l: "${l.mac},${l.ip},${l.hostname}") cfg.staticLeases;
      };
    };
  };
}

