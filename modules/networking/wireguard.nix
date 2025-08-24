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
    peers = mkOption {
      type = types.listOf types.attrs;
      default = [];
    };
  };

  config = mkIf cfg.enable {
    services.wireguard.interfaces.wg0 = {
      ips = [ "10.70.0.1/24" ];
      listenPort = cfg.listenPort;
      peers = cfg.peers;
    };

    networking.firewall = {
      interfaces."${wanIface}".allowedUDPPorts = [ cfg.listenPort ];
      extraCommands = ''
        nft add rule inet filter forward iifname wg0 oifname ${mgmtIface} ip daddr 192.168.70.0/24 counter accept
        nft add rule inet filter forward iifname wg0 counter drop
      '';
      extraStopCommands = ''
        nft delete rule inet filter forward iifname wg0 oifname ${mgmtIface} ip daddr 192.168.70.0/24 counter accept
        nft delete rule inet filter forward iifname wg0 counter drop
      '';
    };
  };
}
