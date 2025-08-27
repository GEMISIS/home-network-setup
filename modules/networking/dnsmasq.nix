{ config, lib, ... }:

with lib;

let
  cfg = config.router.services.dnsmasq;
  vl  = config.router.vlans;
  hw  = config.router.hw;

  mkIP = vid: "192.168.${toString vid}";

  trunkVids = [ vl.iot vl.autom vl.guest vl.home vl.media vl.ha ];
  allVids = trunkVids ++ [ vl.cams vl.mgmt ];

  mkRange = vid: "${mkIP vid}.100,${mkIP vid}.199,255.255.255.0,12h";
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
        except-interface = hw.wan.iface;
        dhcp-range      = map mkRange allVids;
        dhcp-host       = map (l: "${l.mac},${l.ip},${l.hostname}") cfg.staticLeases;
        dhcp-authoritative = true;
      };
    };
    systemd.services.dnsmasq.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}

