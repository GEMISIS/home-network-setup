{ config, lib, ... }:

with lib;

let
  cfg = config.router.networking.policies;
  vlans = config.router.vlans;
  hw = config.router.hw;
  wan  = hw.wan.iface;

  trunk = hw.trunk.iface;
  camsIf = hw.cameras.iface;
  mgmtIf = hw.mgmt.iface;
  trunkVids = [ vlans.iot vlans.autom vlans.guest vlans.home ];

  ifaceFor = vid:
    if elem vid trunkVids then "${trunk}.${toString vid}"
    else if vid == vlans.media then trunk
    else if vid == vlans.cams then "${camsIf}.${toString vlans.cams}"
    else mgmtIf;

  mkSet = lst: "{ " + concatStringsSep ", " (map toString lst) + " }";
  internalIfaces = map ifaceFor [
    vlans.iot vlans.autom vlans.guest vlans.home
    vlans.media vlans.cams vlans.mgmt
  ];
  internalIfaceSet = "{ " + concatStringsSep ", " (map (i: "\"${i}\"") internalIfaces) + " }";
  rfc1918Addrs = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }";
  chromecastTcp = "{ 1900, 8008, 8009, 8443 }";
  chromecastUdp = "{ 1900, 5353 }";
  chromecastIfaces = "{ \"${ifaceFor vlans.home}\", \"${ifaceFor vlans.media}\" }";
  haIp = "192.168.50.10";
  macMiniIp = cfg.macMiniIp;

in {
  options.router.networking.policies = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    haToAutomationPorts = mkOption {
      type = types.listOf types.int;
      default = [ 6053 1900 8008 8009 8443 5540 5541 631 9100 515 ];
    };
    haToIotPorts = mkOption {
      type = types.listOf types.int;
      default = [ 6053 1900 8008 8009 8443 5540 5541 ];
    };
    haToCamerasPorts = mkOption {
      type = types.listOf types.int;
      default = [ 554 80 443 ];
    };
    printerSubnet = mkOption {
      type = types.str;
      default = "192.168.20.0/24";
      description = "Subnet (CIDR) containing the isolated IoT printer.";
    };
    printerTcpPorts = mkOption {
      type = types.listOf types.int;
      default = [ 631 9100 515 ];
      description = "TCP ports exposed by the network printer (IPP, JetDirect, LPD).";
    };
    printerUdpPorts = mkOption {
      type = types.listOf types.int;
      default = [ 631 ];
      description = "UDP ports exposed by the network printer (IPP discovery, etc.).";
    };
    haHomeKitRange = mkOption {
      type = types.str;
      default = "51720-51750";
    };
    mgmtAdminPorts = mkOption {
      type = types.listOf types.int;
      default = [ 22 443 ];
    };
    macMiniIp = mkOption {
      type = types.str;
      default = "192.168.70.100";
      description = "IP address of the Mac Mini on the management network.";
    };
    macMiniPorts = mkOption {
      type = types.listOf types.int;
      default = [ 8443 ];
      description = "Ports exposed by the Mac Mini to other VLANs.";
    };
    haMacMiniPorts = mkOption {
      type = types.listOf types.int;
      default = [ 11434 ];
      description = "Ports Home Assistant may access on the Mac Mini.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraForwardRules = ''
      # Home Assistant to Automation VLAN
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname "${ifaceFor vlans.autom}" tcp dport ${mkSet cfg.haToAutomationPorts} accept
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname "${ifaceFor vlans.autom}" udp dport ${mkSet cfg.haToAutomationPorts} accept

      # Home Assistant to IoT VLAN
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname "${ifaceFor vlans.iot}" tcp dport ${mkSet cfg.haToIotPorts} accept
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname "${ifaceFor vlans.iot}" udp dport ${mkSet cfg.haToIotPorts} accept

      # Home Assistant to Cameras VLAN
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname "${ifaceFor vlans.cams}" tcp dport ${mkSet cfg.haToCamerasPorts} accept
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname "${ifaceFor vlans.cams}" udp dport ${mkSet cfg.haToCamerasPorts} accept

      # Allow family devices to reach the printer on the automation VLAN
      iifname "${ifaceFor vlans.home}" oifname "${ifaceFor vlans.autom}" ip daddr ${cfg.printerSubnet} tcp dport ${mkSet cfg.printerTcpPorts} accept
      iifname "${ifaceFor vlans.home}" oifname "${ifaceFor vlans.autom}" ip daddr ${cfg.printerSubnet} udp dport ${mkSet cfg.printerUdpPorts} accept

      # Allow guest devices to reach the printer on the automation VLAN
      iifname "${ifaceFor vlans.guest}" oifname "${ifaceFor vlans.autom}" ip daddr ${cfg.printerSubnet} tcp dport ${mkSet cfg.printerTcpPorts} accept
      iifname "${ifaceFor vlans.guest}" oifname "${ifaceFor vlans.autom}" ip daddr ${cfg.printerSubnet} udp dport ${mkSet cfg.printerUdpPorts} accept

      # Home Assistant to Chromecast targets on Home and Media VLANs
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname ${chromecastIfaces} tcp dport ${chromecastTcp} accept
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname ${chromecastIfaces} udp dport ${chromecastUdp} accept

      # Home Assistant HomeKit (TCP range + mDNS)
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} ip daddr ${rfc1918Addrs} tcp dport ${cfg.haHomeKitRange} accept
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} ip daddr ${rfc1918Addrs} udp dport 5353 accept

      # Home Assistant access to Mac Mini for Ollama
      iifname "${ifaceFor vlans.media}" ip saddr ${haIp} oifname "${ifaceFor vlans.mgmt}" ip daddr ${macMiniIp} tcp dport ${mkSet cfg.haMacMiniPorts} accept

      # Management network administrative access
      iifname "${ifaceFor vlans.mgmt}" ip daddr ${rfc1918Addrs} tcp dport ${mkSet cfg.mgmtAdminPorts} accept

      # Access Mac Mini from Home
      iifname "${ifaceFor vlans.home}" oifname "${ifaceFor vlans.mgmt}" ip daddr ${macMiniIp} tcp dport ${mkSet cfg.macMiniPorts} accept
      iifname "${ifaceFor vlans.home}" oifname "${ifaceFor vlans.mgmt}" ip daddr ${macMiniIp} udp dport ${mkSet cfg.macMiniPorts} accept

      # Default deny between RFC1918 subnets
      iifname ${internalIfaceSet} oifname ${internalIfaceSet} ip saddr ${rfc1918Addrs} ip daddr ${rfc1918Addrs} drop

      # Block Automation VLAN from WAN
      iifname "${ifaceFor vlans.autom}" oifname "${wan}" drop

      # Block Cameras VLAN from WAN
      iifname "${ifaceFor vlans.cams}" oifname "${wan}" reject
    '';
  };
}
