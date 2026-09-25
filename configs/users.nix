{ config, lib, pkgs, ... }:
{
  # Users, groups and passwords come only from this config: /etc/passwd,
  # /etc/group and /etc/shadow are regenerated on every activation. On
  # 2026-09-24 a full disk + power loss left /etc/shadow missing and locked
  # out every login; with immutable users that heals on the next boot.
  #
  # No password lives in this repo. The hash is a root-only file created once
  # on the machine (see README); it is never rewritten, so a full disk can't
  # truncate it. If it is missing the account is locked for password auth,
  # but SSH keys still work.
  users.mutableUsers = false;

  users.users = {
    gemisis = {
      isNormalUser = true;
      description = "Gerald's user";
      extraGroups = [ "wheel" ];
      hashedPasswordFile = "/var/lib/secrets/gemisis.hash";
      openssh.authorizedKeys.keyFiles = [
        ../keys/gemisis-quest3.pub
        ../keys/gemisis-mac.pub
      ];
    };
  };

  security.sudo.wheelNeedsPassword = true;
}
