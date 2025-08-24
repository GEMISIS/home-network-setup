{ config, lib, ... }:

with lib;

let
  cfg = config.router.ops.hardening;
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
    services.crowdsec = {
      enable = true;
      bouncer.nftables.enable = true;
    };

    services.openssh = {
      settings =
        {
          ListenAddress = [ "192.168.70.1" "0.0.0.0%wg0" ];
          PasswordAuthentication = "no";
        }
        // (mkIf (cfg.sshAllowedUsers != [ ]) {
          AllowUsers = concatStringsSep " " cfg.sshAllowedUsers;
        });
    };
  };
}
