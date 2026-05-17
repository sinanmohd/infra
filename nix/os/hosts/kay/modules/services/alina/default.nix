{ config, alina, ... }:
let
  domain = "alinafs.com";
in
{
  imports = [ alina.nixosModules.alina ];

  sops.secrets."misc/alina".sopsFile = ./secrets.yaml;

  services.postgresql = {
    ensureDatabases = [ "alina" ];
    ensureUsers = [
      {
        name = "alina";
        ensureDBOwnership = true;
      }
    ];
  };

  services.alina = {
    enable = true;
    port = 8006;
    environmentFile = config.sops.secrets."misc/alina".path;
    settings.server = {
      data = "/hdd/alina";
      file_size_limit = 1024 * 1024 * 1024; # 1GB
      public_url = "https://${domain}";
    };
  };
}
