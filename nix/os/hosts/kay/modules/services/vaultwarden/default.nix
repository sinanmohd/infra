{ config, lib, ... }:
let
  domain = config.global.userdata.domain;
in
{
  sops.secrets = {
    "vaultwarden/env".sopsFile = ./secrets.yaml;
    "vaultwarden/rsa.pem" = {
      sopsFile = ./secrets.yaml;
      owner = config.systemd.services.vaultwarden.serviceConfig.User;
    };
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    configurePostgres = true;
    environmentFile = config.sops.secrets."vaultwarden/env".path;
    config = {
      # Refer to https://github.com/dani-garcia/vaultwarden/blob/main/.env.template
      DOMAIN = "https://vaultwarden.${domain}";
      SIGNUPS_ALLOWED = false;
      RSA_KEY_FILENAME = lib.removeSuffix ".pem" config.sops.secrets."vaultwarden/rsa.pem".path;

      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";

      # https://github.com/dani-garcia/vaultwarden/wiki/SMTP-configuration
      SMTP_HOST = "mail.${domain}";
      SMTP_FROM = "no-reply@${domain}";
      SMTP_FROM_NAME = "Sinan's Vaultwarden server";
      SMTP_PORT = 465;
      SMTP_SECURITY = "force_tls";
      SMTP_USERNAME = "no-reply@${domain}";
    };
  };
}
