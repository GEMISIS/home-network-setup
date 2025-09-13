{ config, lib, pkgs, ... }:
{
  services = {
    journald.extraConfig = ''
      Storage=persistent
      SystemMaxUse=500M
      RuntimeMaxUse=200M
    '';

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
      # TODO: Complete initial setup through the web UI and supply
      #       UniFi login credentials.
    };
  };

  systemd.coredump.enable = true;
}

