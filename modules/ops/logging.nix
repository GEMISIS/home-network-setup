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

        # Resume from where we left off instead of replaying the whole journal
        # on every restart.
        positions.filename = "/var/lib/promtail/positions.yaml";

        clients = [{
          url = "${cfg.lokiUrl}/loki/api/v1/push";
          # Batch and back off so an unreachable/slow Loki just retries
          # harmlessly and never stalls or bloats the router.
          batchwait = "1s";
          batchsize = 1048576; # 1 MiB
          backoff_config = {
            min_period = "500ms";
            max_period = "5m";
            max_retries = 10;
          };
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

    # Keep Promtail as a well-behaved leaf service: it must never be able to
    # take down or slow the router. (This is the "set it up properly" fix.)
    systemd.services.promtail.serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
      MemoryMax = "256M";
      Nice = 10;
      StateDirectory = "promtail"; # ensures /var/lib/promtail exists
    };
  };
}
