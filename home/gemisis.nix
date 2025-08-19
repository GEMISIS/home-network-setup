{ config, pkgs, ... }:
{
  home.username = "gemisis";
  home.homeDirectory = "/home/gemisis";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.vim.enable = true;

  programs.ssh = {
    enable = true;
    startAgent = true;
    knownHosts.github = {
      hostNames = [ "github.com" ];
      publicKey = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
    extraConfig = ''
      Host github.com
        User git
        IdentityFile = ~/.ssh/gemisis-git
        IdentitiesOnly yes
    '';
  };

  programs.git = {
    enable = true;
    config.init.defaultBranch = "main";
  };
}
