# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan and modular configs.
      ./hardware-configuration.nix
      ./configs/services.nix
      ./configs/users.nix
      ./modules/networking/vars.nix
      ./modules/networking/firewall-base.nix
      ./modules/networking/dnsmasq.nix
      ./modules/networking/nat.nix
      ./modules/networking/vlans.nix
      ./modules/networking/firewall-policies.nix
      ./modules/networking/discovery.nix
      ./modules/ops/updates.nix
      ./modules/ops/logging.nix
      ./modules/ops/hardening.nix
      ./modules/ops/monitoring.nix
      ./modules/ops/crowdsec.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "8021q" ];

  # Device basics
  networking.hostName = "McAlister-Home";
  time.timeZone = "America/Los_Angeles";

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
    };
  };

  nixpkgs.config.allowUnfree = true;
  environment.variables.NIXPKGS_ALLOW_UNFREE = "1";

  system.stateVersion = "25.05";

  # NIC roles (final)
  router.hw = {
    wan.iface = "enp8s0"; # 10G to ISP (DHCP; single public IP)
    mgmt.iface = "enp7s0"; # 10G management/office (VLAN 70 access)
    trunk.iface = "enp1s0"; # 2.5G trunk to WAPs and VLAN devices (10/20/30/40/50)
    cameras.iface = "enp2s0"; # 2.5G trunk carrying tagged VLAN 60
  };

  # Core networking
  router.networking = {
    vlans.enable = true;
    firewallBase.enable = true;

    nat = {
      enable = true;
      useDhcpOnWan = true;
      # wanInterface defaults to router.hw.wan.iface
    };
  };

  # DHCP + DNS
  router.services.dnsmasq = {
    enable = true;
    staticLeases = [
      {
        mac = "d8:3a:dd:b7:09:e2";
        ip = "192.168.50.10";
        hostname = "homeassistant";
      }
    ];
  };

  # Inter‑VLAN policies (HA ports + admin)
  router.networking.policies = {
    enable = true;

    # ESPHome, SSDP, Chromecast control, Matter (UDP/TCP 5540 + TCP 5541)
    haToAutomationPorts = [ 6053 1900 8008 8009 8443 5540 5541 ];
    haToCamerasPorts = [ 554 80 443 ];

    # HomeKit bridge TCP range
    haHomeKitRange = "51720-51750";

    mgmtAdminPorts = [ 22 443 ];
  };

  # mDNS reflection for HomeKit + Chromecast (50↔40, 50↔10, 50↔20)
  router.networking.discovery.enable = true;

  # Ops
  router.ops.updates.enable = true;

  router.ops.logging.enable = false;

  router.ops.hardening = {
    enable = true;
    sshAllowedUsers = [ "gemisis" ];
  };

  router.ops.monitoring.enable = true;

  router.ops.crowdsec.enable = false;

  # IPv4 only for now; leave IPv6 disabled/untouched.

  sops = {
    age.keyFile = "/root/age.key";
  };
}

