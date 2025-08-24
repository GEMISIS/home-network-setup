{ config, lib, ... }:

with lib;

let
  cfg = config.router.services.dnsmasq;
  vlanIds = [ 10 20 30 40 50 51 60 70 ];
  mkBr = vid: "br${toString vid}";
  mkIP = vid: "192.168.${toString vid}";
  mkRange = vid: "${mkBr vid},${mkIP vid}.100,${mkIP vid}.199,255.255.255.0,12h";
  mkOptions = vid: [
    "${mkBr vid},option:router,${mkIP vid}.1"
    "${mkBr vid},option:dns-server,${mkIP vid}.1"
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
        interface   = map mkBr vlanIds;
        dhcp-range  = map mkRange vlanIds;
        dhcp-option = concatMap mkOptions vlanIds;
        dhcp-host   = map (l: "${l.mac},${l.ip},${l.hostname}") cfg.staticLeases;
      };
    };
  };
}

