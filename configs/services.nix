{ config, lib, pkgs, ... }:
{
  services = {
    journald = {
      extraConfig = ''
        Storage=persistent
        SystemMaxUse=500M
        RuntimeMaxUse=200M
        RateLimitInterval=15s
        RateLimitBurst=5000
      '';
      storage = "persistent";
    };

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
      };
    };

    unifi = {
      enable = true;
      openFirewall = false;
      mongodbPackage = pkgs.mongodb-ce;
    };
  };

  systemd.coredump.enable = true;

  # Enable docker
  virtualisation.docker.enable = true;

  # Systemd unit that runs the Open WebUI container
  systemd.services.open-webui-docker = {
    description = "Open WebUI (Docker)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" "docker.service" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";

      ExecStart = ''
        ${pkgs.docker}/bin/docker run \
          --name open-webui \
          --rm \
          -p 8008:8080 \
          -v /var/lib/open-webui:/app/backend/data \
          ghcr.io/open-webui/open-webui:0.6.43
      '';

      ExecStop = ''
        ${pkgs.docker}/bin/docker stop open-webui || true
      '';
    };
  };
}

