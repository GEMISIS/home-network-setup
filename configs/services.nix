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
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = true;
        KbdInteractiveAuthentication = false;
      };
    };
  };

  systemd.coredump.enable = true;
}

