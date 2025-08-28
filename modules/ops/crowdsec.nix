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

    environment.etc."crowdsec/config.yaml".source = pkgs.crowdsec + "/share/crowdsec/config/config.yaml";
    environment.etc."crowdsec/acquis.yaml".source = pkgs.crowdsec + "/share/crowdsec/config/acquis.yaml";
    environment.etc."crowdsec/profiles.yaml".source = pkgs.crowdsec + "/share/crowdsec/config/profiles.yaml";
    environment.etc."crowdsec/console.yaml".source = pkgs.crowdsec + "/share/crowdsec/config/console.yaml";
    environment.etc."crowdsec/local_api_credentials.yaml".source = pkgs.crowdsec + "/share/crowdsec/config/local_api_credentials.yaml";

    sops.secrets.crowdsecBouncerKey = {
      sopsFile = ../../secrets/crowdsec.yaml;
      key = "crowdsec_bouncer_key";
      restartUnits = [ "crowdsec-firewall-bouncer.service" ];
    };

    sops.templates."crowdsec-firewall-bouncer.yaml".content = ''
      api_url: http://127.0.0.1:8080/
      api_key: {{ .crowdsecBouncerKey }}
      mode: nftables
    '';

    environment.etc."crowdsec/bouncers/crowdsec-firewall-bouncer.yaml".source =
      config.sops.templates."crowdsec-firewall-bouncer.yaml".path;

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
        ExecStart = "${pkgs.crowdsec-firewall-bouncer}/bin/cs-firewall-bouncer -c /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml";
        Restart = "on-failure";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
