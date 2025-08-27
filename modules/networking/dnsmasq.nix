{ config, lib, ... }:

with lib;

let
  cfg = config.router.services.dnsmasq;
  vl  = config.router.vlans;
  hw  = config.router.hw;

  mkNet = vid: "192.168.${toString vid}";
  mkGW = vid: "${mkNet vid}.1";

  trunkVids = [ vl.iot vl.autom vl.guest vl.home vl.ha ];
  allVids = trunkVids ++ [ vl.media vl.cams vl.mgmt ];
  allIfaces = map ifaceFor allVids;

  mkRange = vid:
    let
      iface = ifaceFor vid;
    in "interface:${iface},${mkNet vid}.100,${mkNet vid}.199,255.255.255.0,12h";

  ifaceFor = vid:
    if elem vid trunkVids then "${hw.trunk.iface}.${toString vid}"
    else if vid == vl.media then hw.trunk.iface
    else if vid == vl.cams then "${hw.cameras.iface}.${toString vl.cams}"
    else hw.mgmt.iface;

  mkRouterOpt = vid: "interface:${ifaceFor vid},option:router,${mkGW vid}";
  mkDnsOpt    = vid: "interface:${ifaceFor vid},option:dns-server,${mkGW vid}";
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
        interface       = allIfaces;
        listen-address  = map mkGW allVids;
        bind-dynamic    = true;
        except-interface = [ hw.wan.iface ];
        dhcp-range      = map mkRange allVids;
        dhcp-host       = map (l: "${l.mac},${l.ip},${l.hostname}") cfg.staticLeases;
        dhcp-option     = (map mkRouterOpt allVids) ++ (map mkDnsOpt allVids);
        dhcp-authoritative = true;
      };
    };
    systemd.services.dnsmasq.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}

