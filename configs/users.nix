{ config, lib, pkgs, ... }:
{
  # Users, groups and passwords come only from this config: /etc/passwd,
  # /etc/group and /etc/shadow are regenerated on every activation. On
  # 2026-09-24 a full disk + power loss left /etc/shadow missing and locked
  # out every login; with immutable users that heals on the next boot.
  #
  # There are no passwords at all: login is SSH-key only, and sudo
  # authenticates against the forwarded SSH agent (`ssh -A`) instead of a
  # password. Console recovery is the systemd-boot editor + systemd.debug_shell.
  users.mutableUsers = false;

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

  # Checks the agent against /etc/ssh/authorized_keys.d/%u, which is
  # root-owned and generated from the keyFiles above.
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;

  security.sudo.wheelNeedsPassword = true;
}
