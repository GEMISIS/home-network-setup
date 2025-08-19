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

  # Ensure system logs persist across reboots and are sized reasonably
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=500M
    RuntimeMaxUse=200M
  '';

  # Capture program crashes for later inspection
  systemd.coredump.enable = true;

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
      ./keys/gemisis-quest3.pub
      ./keys/gemisis-mac.pub
    ];
  };
  security.sudo.wheelNeedsPassword = true;

  system.stateVersion = "25.05";

}

