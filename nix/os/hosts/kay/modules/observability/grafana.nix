{ config, ... }:
let
  domain = "grafana." + config.global.userdata.domain;
  user = config.global.userdata.name;
  email = config.global.userdata.email;
in
{
  sops.secrets."grafana/password" = {
    sopsFile = ./secrets.yaml;
    owner = "grafana";
    group = "grafana";
  };

  services = {
    postgresql = {
      ensureDatabases = [ "grafana" ];
      ensureUsers = [
        {
          name = "grafana";
          ensureDBOwnership = true;
        }
      ];
    };

    grafana = {
      enable = true;

      settings = {
        database = {
          type = "postgres";
          name = "grafana";
          user = "grafana";
          host = "/run/postgresql";
        };

        server = {
          inherit domain;
          enforce_domain = true;
        };

        security = {
          admin_user = user;
          admin_email = email;
          admin_password = "$__file{${config.sops.secrets."grafana/password".path}}";
          secret_key = "SW2YcwTIb9zpOOhoPsMm";
        };
      };
    };
  };
}
