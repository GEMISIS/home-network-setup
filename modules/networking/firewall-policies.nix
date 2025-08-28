{ config, lib, ... }:

with lib;

let
  cfg = config.router.networking.policies;
  vlans = config.router.vlans;
  hw   = config.router.hw;
  wan  = hw.wan.iface;

  trunkVids = [ vlans.iot vlans.autom vlans.guest vlans.home vlans.ha ];
  ifaceFor = vid:
    if elem vid trunkVids then "${hw.trunk.iface}.${toString vid}"
    else if vid == vlans.media then hw.trunk.iface
    else if vid == vlans.cams then hw.cameras.iface
    else hw.mgmt.iface;

  mkSet = lst: "{ " + concatStringsSep ", " (map toString lst) + " }";
  internalIfaces = map ifaceFor [
    vlans.iot vlans.autom vlans.guest vlans.home
    vlans.media vlans.ha vlans.cams vlans.mgmt
  ];
  internalIfaceSet = "{ " + concatStringsSep ", " (map (i: "\"${i}\"") internalIfaces) + " }";
  rfc1918Addrs = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }";
  chromecastTcp = "{ 1900, 8008, 8009, 8443 }";
  chromecastUdp = "{ 1900, 5353 }";
  chromecastIfaces = "{ \"${ifaceFor vlans.home}\", \"${ifaceFor vlans.media}\" }";

in {
  options.router.networking.policies = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    haToAutomationPorts = mkOption {
      type = types.listOf types.int;
      default = [ 6053 1900 8008 8009 8443 5540 5541 ];
    };
    haToIotPorts = mkOption {
      type = types.listOf types.int;
      default = [ 6053 1900 8008 8009 8443 5540 5541 ];
    };
    haToCamerasPorts = mkOption {
      type = types.listOf types.int;
      default = [ 554 80 443 ];
    };
    haHomeKitRange = mkOption {
      type = types.str;
      default = "51720-51750";
    };
    mgmtAdminPorts = mkOption {
      type = types.listOf types.int;
      default = [ 22 443 ];
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraForwardRules = ''
      # Home Assistant to Automation VLAN
      iifname "${ifaceFor vlans.ha}" oifname "${ifaceFor vlans.autom}" tcp dport ${mkSet cfg.haToAutomationPorts} accept
      iifname "${ifaceFor vlans.ha}" oifname "${ifaceFor vlans.autom}" udp dport ${mkSet cfg.haToAutomationPorts} accept

      # Home Assistant to IoT VLAN
      iifname "${ifaceFor vlans.ha}" oifname "${ifaceFor vlans.iot}" tcp dport ${mkSet cfg.haToIotPorts} accept
      iifname "${ifaceFor vlans.ha}" oifname "${ifaceFor vlans.iot}" udp dport ${mkSet cfg.haToIotPorts} accept

      # Home Assistant to Cameras VLAN
      iifname "${ifaceFor vlans.ha}" oifname "${ifaceFor vlans.cams}" tcp dport ${mkSet cfg.haToCamerasPorts} accept
      iifname "${ifaceFor vlans.ha}" oifname "${ifaceFor vlans.cams}" udp dport ${mkSet cfg.haToCamerasPorts} accept

      # Home Assistant to Chromecast targets on Home and Media VLANs
      iifname "${ifaceFor vlans.ha}" oifname ${chromecastIfaces} tcp dport ${chromecastTcp} accept
      iifname "${ifaceFor vlans.ha}" oifname ${chromecastIfaces} udp dport ${chromecastUdp} accept

      # Home Assistant HomeKit (TCP range + mDNS)
      iifname "${ifaceFor vlans.ha}" ip daddr ${rfc1918Addrs} tcp dport ${cfg.haHomeKitRange} accept
      iifname "${ifaceFor vlans.ha}" ip daddr ${rfc1918Addrs} udp dport 5353 accept

      # Management network administrative access
      iifname "${ifaceFor vlans.mgmt}" ip daddr ${rfc1918Addrs} tcp dport ${mkSet cfg.mgmtAdminPorts} accept

      # Default deny between RFC1918 subnets
      iifname ${internalIfaceSet} oifname ${internalIfaceSet} ip saddr ${rfc1918Addrs} ip daddr ${rfc1918Addrs} drop

      # Explicitly reject Cameras VLAN to WAN
      iifname "${ifaceFor vlans.cams}" oifname "${wan}" counter reject
    '';
  };
}
