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
  };

  systemd.coredump.enable = true;
}

