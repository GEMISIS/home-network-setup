{ config, lib, ... }:

with lib;

let
  cfg = config.router.ops.updates;
in {
  options.router.ops.updates = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic NixOS upgrades.";
    };
  };

  config = mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      dates = "03:30";
    };

    users.motd = "Rollback: sudo nixos-rebuild switch --rollback\n";
  };
}

