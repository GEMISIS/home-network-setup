{ config, lib, ... }:

with lib;

let
  cfg = config.router.services.dnsmasq;
  vl  = config.router.vlans;
  hw  = config.router.hw;

  mkIP = vid: "192.168.${toString vid}";
  mkRouterIP = vid: "${mkIP vid}.1";

  trunkVids = [ vl.iot vl.autom vl.guest vl.home vl.media vl.ha ];
  trunkIfaces = map (v: { iface = "${hw.trunk.iface}.${toString v}"; vid = v; }) trunkVids;

  vlanIfaces = trunkIfaces ++ [
    { iface = "${hw.cameras.iface}.${toString vl.cams}"; vid = vl.cams; }
    { iface = hw.mgmt.iface; vid = vl.mgmt; }
  ];

  mkRange = e: "${e.iface},${mkIP e.vid}.100,${mkIP e.vid}.199,255.255.255.0,12h";
  mkOptions = e: [
    "${e.iface},option:router,${mkRouterIP e.vid}"
    "${e.iface},option:dns-server,${mkRouterIP e.vid}"
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
        bind-interfaces = true;
        bind-dynamic    = true;
        interface       = map (e: e.iface) vlanIfaces;
        except-interface = hw.wan.iface;
        dhcp-range      = map mkRange vlanIfaces;
        dhcp-option     = concatMap mkOptions vlanIfaces;
        dhcp-host       = map (l: "${l.mac},${l.ip},${l.hostname}") cfg.staticLeases;
        dhcp-authoritative = true;
      };
    };
    systemd.services.dnsmasq = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };
  };
}

