{ config, lib, ... }:

with lib;

let
  cfg = config.router.services.dnsmasq;
  vl  = config.router.vlans;
  hw  = config.router.hw;

  mkIP = vid: "192.168.${toString vid}";

  trunkVids = [ vl.iot vl.autom vl.guest vl.home vl.ha ];
  allVids   = trunkVids ++ [ vl.media vl.cams vl.mgmt ];

  ifaceFor = vid:
    if elem vid trunkVids then "${hw.trunk.iface}.${toString vid}"
    else if vid == vl.media then hw.trunk.iface
    else if vid == vl.cams then "${hw.cameras.iface}.${toString vl.cams}"
    else hw.mgmt.iface;

  mkRange = vid:
    let
      iface = ifaceFor vid;
    in
      "interface:${iface},${mkIP vid}.100,${mkIP vid}.199,255.255.255.0,12h";

  mkOptions = vid:
    let
      gw    = "${mkIP vid}.1";
      iface = ifaceFor vid;
    in [
      "interface:${iface},option:router,${gw}"
      "interface:${iface},option:dns-server,${gw}"
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
        bind-dynamic    = true;
        interface       = map ifaceFor allVids;
        except-interface = [ hw.wan.iface ];
        dhcp-range      = map mkRange allVids;
        dhcp-option     = concatMap mkOptions allVids;
        dhcp-host       = map (l: "${l.mac},${l.ip},${l.hostname}") cfg.staticLeases;
        dhcp-authoritative = true;
      };
    };
    systemd.services.dnsmasq = {
      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}

