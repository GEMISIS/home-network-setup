{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.router.ops.crowdsec;
in {
  options.router.ops.crowdsec = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable CrowdSec agent with nftables bouncer.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.crowdsec pkgs.crowdsec-firewall-bouncer ];

    environment.etc."crowdsec/config.yaml".source = pkgs.crowdsec + "/etc/crowdsec/config.yaml";
    environment.etc."crowdsec/bouncers/crowdsec-firewall-bouncer.yaml".source = pkgs.crowdsec-firewall-bouncer + "/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml";

    systemd.services.crowdsec = {
      description = "CrowdSec agent";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.crowdsec}/bin/crowdsec -c /etc/crowdsec/config.yaml";
        Restart = "on-failure";
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.crowdsec-firewall-bouncer = {
      description = "CrowdSec nftables bouncer";
      after = [ "crowdsec.service" "network-online.target" ];
      wants = [ "crowdsec.service" "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.crowdsec-firewall-bouncer}/bin/crowdsec-firewall-bouncer -c /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml";
        Restart = "on-failure";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
