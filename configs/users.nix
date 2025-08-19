{ config, lib, pkgs, ... }:
{
  users.users = {
    gemisis = {
      isNormalUser = true;
      description = "Gerald's user";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keyFiles = [
        ../keys/gemisis-quest3.pub
        ../keys/gemisis-mac.pub
      ];
    };
  };

  security.sudo.wheelNeedsPassword = true;
}

