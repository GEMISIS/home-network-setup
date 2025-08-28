{ config, lib, ... }:

with lib;

let
  cfg = config.router.vpn.wireguard;
  wanIface = config.router.hw.wan.iface;
  mgmtIface = config.router.hw.mgmt.iface;
in {
  options.router.vpn.wireguard = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    listenPort = mkOption {
      type = types.int;
      default = 51820;
    };
    privateKeyFile = mkOption {
      type = types.str;
      description = "Path to the WireGuard private key file.";
    };
    peers = mkOption {
      type = types.listOf types.attrs;
      default = [];
    };
  };

  config = mkIf cfg.enable {
    networking.wireguard.interfaces.wg0 = {
      ips = [ "10.70.0.1/24" ];
      listenPort = cfg.listenPort;
      privateKeyFile = cfg.privateKeyFile;
      peers = cfg.peers;
    };

    networking.firewall.interfaces."${wanIface}".allowedUDPPorts = [ cfg.listenPort ];
    networking.firewall.extraForwardRules = lib.mkAfter ''
      iifname "wg0" oifname "${mgmtIface}" ip daddr 192.168.70.0/24 accept
      iifname "wg0" drop
    '';
  };
}
