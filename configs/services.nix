{ config, lib, pkgs, ... }:
{
  services = {
    open-webui = {
      enable = true;
      port = 8008;
      host = "0.0.0.0";
    };

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
      openFirewall = false; # manual firewall rules below
    };
  };

  systemd.coredump.enable = true;
}

