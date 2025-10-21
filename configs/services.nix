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
      openFirewall = false; # manual firewall rules below
    };
  };

  systemd.coredump.enable = true;
}

