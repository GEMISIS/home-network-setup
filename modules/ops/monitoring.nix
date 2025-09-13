{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.router.ops.monitoring;
  mgmtIp = lib.head (lib.splitString "/" config.router.addr4.base."70");
in
{
  options.router.ops.monitoring = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Grafana, Prometheus, Loki, and Promtail stack.";
    };
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = 3020;
      exporters = {
        node = {
          enable = true;
          port = 3021;
          enabledCollectors = [ "systemd" ];
        };
      };
      scrapeConfigs = [{
        job_name = "nodes";
        static_configs = [{
          targets = [
            "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
          ];
        }];
      }];
    };

    services.loki = {
      enable = true;
      configuration = {
        server.http_listen_port = 3030;
        auth_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = { store = "inmemory"; };
              replication_factor = 1;
            };
          };
          chunk_idle_period = "1h";
          max_chunk_age = "1h";
          chunk_target_size = 999999;
          chunk_retain_period = "30s";
        };

        schema_config = {
          configs = [{
            from = "2022-06-06";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = { prefix = "index_"; period = "24h"; };
          }];
        };

        storage_config = {
          boltdb_shipper = {
            active_index_directory = "/var/lib/loki/boltdb-shipper-active";
            cache_location = "/var/lib/loki/boltdb-shipper-cache";
            cache_ttl = "24h";
          };

          filesystem = { directory = "/var/lib/loki/chunks"; };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };

        compactor = {
          working_directory = "/var/lib/loki";
          compactor_ring.kvstore.store = "inmemory";
        };
      };
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 3031;
          grpc_listen_port = 0;
        };
        positions.filename = "/tmp/positions.yaml";
        clients = [{
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
        }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_port = 3010;
          root_url = "http://${mgmtIp}:8010";
          protocol = "http";
          http_addr = "127.0.0.1";
        };
        analytics.reporting_enabled = false;
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          }
        ];
      };
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      upstreams = {
        grafana.servers."127.0.0.1:${toString config.services.grafana.settings.server.http_port}" = { };
        prometheus.servers."127.0.0.1:${toString config.services.prometheus.port}" = { };
        loki.servers."127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}" = { };
        promtail.servers."127.0.0.1:${toString config.services.promtail.configuration.server.http_listen_port}" = { };
      };
      virtualHosts = {
        grafana = {
          locations."/" = {
            proxyPass = "http://grafana";
            proxyWebsockets = true;
          };
          listen = [{ addr = mgmtIp; port = 8010; }];
        };
        prometheus = {
          locations."/".proxyPass = "http://prometheus";
          listen = [{ addr = mgmtIp; port = 8020; }];
        };
        loki = {
          locations."/".proxyPass = "http://loki";
          listen = [{ addr = mgmtIp; port = 8030; }];
        };
        promtail = {
          locations."/".proxyPass = "http://promtail";
          listen = [{ addr = mgmtIp; port = 8031; }];
        };
      };
    };
  };
}
