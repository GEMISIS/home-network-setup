{ config, lib, ... }:

with lib;

let
  cfg = config.router.ops.hardening;
  mgmtVid = toString config.router.vlans.mgmt;
  mgmtIp = config.router.addr4.base."${mgmtVid}".address;
  homeVid = toString config.router.vlans.home;
  homeIp = config.router.addr4.base."${homeVid}".address;
in
{
  options.router.ops.hardening = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable operational security hardening.";
    };

    sshAllowedUsers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of users allowed to access SSH.";
    };
  };

  config = mkIf cfg.enable {
    services.openssh = {
      settings =
        {
          # Restrict SSH to management, home networks and WireGuard interface
          ListenAddress = [ mgmtIp homeIp "0.0.0.0%wg0" ];
          PasswordAuthentication = "no";
        }
        // (mkIf (cfg.sshAllowedUsers != [ ]) {
          AllowUsers = cfg.sshAllowedUsers;
        });
    };
  };
}
