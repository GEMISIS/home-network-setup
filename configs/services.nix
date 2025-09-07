{ config, lib, pkgs, ... }:
{
  services = {
    journald.extraConfig = ''
      Storage=persistent
      SystemMaxUse=500M
      RuntimeMaxUse=200M
    '';

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
      };
    };

    loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server.http_listen_port = 3100;
        common = {
          instance_addr = "127.0.0.1";
          path_prefix = "/var/lib/loki";
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
        };
        schema_config.configs = [{
          from = "2020-10-24";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v11";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
        storage_config = {
          filesystem.directory = "/var/lib/loki/chunks";
          boltdb_shipper = {
            active_index_directory = "/var/lib/loki/index";
            cache_location = "/var/lib/loki/cache";
          };
        };
        ruler.storage = {
          type = "local";
          local.directory = "/var/lib/loki/rules";
        };

        limits_config = {
          allow_structured_metadata = false;
        };
      };
    };
  };

  systemd.coredump.enable = true;
}

