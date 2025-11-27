{ config, pkgs, ... }:
{
  home.username = "gemisis";
  home.homeDirectory = "/home/gemisis";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  programs.vim.enable = true;

  services.ssh-agent.enable = true;
  
  programs.ssh.matchBlocks."github.com" = {
    user = "git";
    identityFile = "~/.ssh/gemisis-git";
    identitiesOnly = true;

  };
  #programs.ssh = {
  #  enable = true;
  #  matchBlocks = {
  #    "github.com" = {
  #      user = "git";
  #      identityFile = "~/.ssh/gemisis-git";
  #      identitiesOnly = true;
  #    };
  #  };
  #};

  home.file.".ssh/gemisis-git" = {
    source = config.lib.file.mkOutOfStoreSymlink "/persist/ssh/gemisis-git";
  };

  home.file.".ssh/known_hosts" = {
    force = true;
    text = ''
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "GEMISIS";
      user.email = "gemisis@users.noreply.github.com";
      init.defaultBranch = "main";
    };
  };
}
