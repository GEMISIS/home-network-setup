{ config, lib, ... }:

with lib;

let
  cfg = config.router.ops.logging;
in {
  options.router.ops.logging = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Promtail for system logging.";
    };
    lokiUrl = mkOption {
      type = types.str;
      default = "http://192.168.70.5:3100";
      description = "URL of the Loki server.";
    };
  };

  config = mkIf cfg.enable {
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        clients = [{
          url = "${cfg.lokiUrl}/loki/api/v1/push";
        }];
        scrape_configs = [{
          job_name = "journald";
          journal = {
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
          relabel_configs = [{
            source_labels = ["__journal__systemd_unit"];
            target_label = "unit";
          }];
        }];
      };
    };
  };
}
