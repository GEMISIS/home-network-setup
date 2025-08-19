{ config, pkgs, ... }:
{
  home.username = "gemisis";
  home.homeDirectory = "/home/gemisis";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.vim.enable = true;

  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    knownHosts.github = {
      hostNames = [ "github.com" ];
      publicKey = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
    extraConfig = ''
      Host github.com
        User git
        IdentityFile ~/.ssh/gemisis-git
        IdentitiesOnly yes
    '';
  };

  programs.git = {
    enable = true;
    userName = "Gerald McAlister";
    userEmail = "gerald@example.com";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };
}
