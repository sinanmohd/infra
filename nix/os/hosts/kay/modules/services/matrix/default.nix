{
  config,
  pkgs,
  lib,
  ...
}:

let
  domain = config.global.userdata.domain;
  database = {
    connection_string = "postgres:///dendrite?host=/run/postgresql";
    max_open_conns = 90;
    max_idle_conns = 5;
    conn_max_lifetime = -1;
  };
in
{
  sops.secrets."matrix-${domain}/key".sopsFile = ./secrets.yaml;
  systemd.services.dendrite.after = [ "postgresql.service" ];

  services = {
    postgresql = {
      ensureDatabases = [ "dendrite" ];
      ensureUsers = [
        {
          name = "dendrite";
          ensureDBOwnership = true;
        }
      ];
    };

    dendrite = {
      enable = true;
      package =
        (pkgs.dendrite.override {
          buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_27; };
        }).overrideAttrs
          (oldAttrs: rec {
            pname = "zendrite";
            version = "3.6.0";

            src = pkgs.fetchgit {
              url = "https://codefloe.com/pat-s/zendrite.git";
              rev = "refs/tags/v${version}";
              hash = "sha256-KKz37VWn1pSYi9Fcy/SzxBv94re3I7ze7Bp9AAxkdzg=";
            };

            subPackages = [
              # The server
              "cmd/zendrite"
              # admin tools
              "cmd/create-account"
              "cmd/generate-config"
              "cmd/generate-keys"
              "cmd/resolve-state"
              ## curl, but for federation requests, only useful for developers
              # "cmd/furl"
              ## an internal tool for upgrading ci tests, only relevant for developers
              # "cmd/dendrite-upgrade-tests"
            ];

            vendorHash = "sha256-NLEmUNeeurH7MVJ4Zzm38dMeSxMd8IG8h6a34RqAJJo=";

            meta = {
              homepage = " https://zendrite.pat-s.me";
              mainProgram = "zendrite";
              description = "An opinionated fork of element-hq/dendrite https://zendrite.pat-s.me";
              changelog = "https://codefloe.com/pat-s/zendrite/releases/tag/v${version}";
              license = lib.licenses.agpl3Plus;
              platforms = lib.platforms.unix;
            };
          });

      loadCredential = [
        "private_key:${config.sops.secrets."matrix-${domain}/key".path}"
      ];

      settings = {
        sync_api.search = {
          enabled = true;
          index_path = "/var/lib/dendrite/searchindex";
        };
        global = {
          metrics.enabled = true;
          server_name = domain;
          private_key = "$CREDENTIALS_DIRECTORY/private_key";
          trusted_third_party_id_servers = [
            "matrix.org"
            "vector.im"
          ];
          inherit database;
          jetstream.storage_path = "/var/lib/dendrite";
        };
        logging = [
          {
            type = "std";
            level = "warn";
          }
        ];
        mscs = {
          inherit database;
          mscs = [ "msc2836" ];
        };
        sync_api = {
          inherit database;
          real_ip_header = "X-Real-IP";
        };
        media_api = {
          inherit database;
          dynamic_thumbnails = true;
          max_file_size_bytes = 12800000000;
        };
        federation_api = {
          inherit database;
          send_max_retries = 8;
          key_perspectives = [
            {
              server_name = "matrix.org";
              keys = [
                {
                  key_id = "ed25519:auto";
                  public_key = "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
                }
                {
                  key_id = "ed25519:a_RXGa";
                  public_key = "l8Hft5qXKn1vfHrg3p4+W8gELQVo8N13JkluMfmn2sQ";
                }
              ];
            }
          ];
        };

        app_service_api = {
          inherit database;
        };
        room_server = {
          inherit database;
        };
        push_server = {
          inherit database;
        };
        relay_api = {
          inherit database;
        };
        key_server = {
          inherit database;
        };
        user_api = {
          account_database = database;
          device_database = database;
        };
      };
    };
  };
}
