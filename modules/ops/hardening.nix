{ config, lib, ... }:

with lib;

let
  cfg = config.router.ops.hardening;
  mgmtVid = toString config.router.vlans.mgmt;
  mgmtIp = elemAt (splitString "/" config.router.addr4.base."${mgmtVid}") 0;
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
    # crowdsec module not present in current nixpkgs; relying on nftables rules only.
    services.openssh = {
      settings =
        {
          # Restrict SSH to management network and WireGuard interface
          ListenAddress = [ mgmtIp "0.0.0.0%wg0" ];
          PasswordAuthentication = "no";
        }
        // (mkIf (cfg.sshAllowedUsers != [ ]) {
          AllowUsers = cfg.sshAllowedUsers;
        });
    };
  };
}
