# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Programs we need by default
  programs.vim.enable = true;
  programs.ssh = {
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
    config = {
      init.defaultBranch = "main";
    };
  };

  # Device basics
  networking.hostName = "McAlister-Home";
  time.timeZone = "America/Los_Angeles";

  # Setup SSH Access
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.gemisis = {
    isNormalUser = true;
    description = "Gerald's user";
    extraGroups = [ "wheel" ]; # Allow sudo
    openssh.authorizedKeys.keyFiles = [
      /etc/nixos/keys/gemisis-quest3.pub
      /etc/nixos/keys/gemisis-mac.pub
    ];
  };
  security.sudo.wheelNeedsPassword = true;

  system.stateVersion = "25.05";

}

