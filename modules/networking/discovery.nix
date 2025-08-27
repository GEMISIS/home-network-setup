{ config, lib, ... }:

with lib;

let
  cfg = config.router.networking.discovery;
  hw = config.router.hw;
  vlans = config.router.vlans;
  trunk = hw.trunk.iface;
  mdnsPort = 5353;

  allowedIfaces = map (v: if v == vlans.home then trunk else "${trunk}.${toString v}") [ vlans.ha vlans.home vlans.media vlans.iot vlans.autom ];
  firewallIfaces = genAttrs allowedIfaces (_: { allowedUDPPorts = [ mdnsPort ]; });
in
{
  imports = [ ./vars.nix ];

  options.router.networking.discovery.enable = mkOption {
    type = types.bool;
    default = false;
    description = "Enable mDNS discovery bridging via Avahi reflector.";
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      reflector = true;
      ipv6 = false;
      allowInterfaces = allowedIfaces;
    };

    networking.firewall.interfaces = firewallIfaces;
  };
}
