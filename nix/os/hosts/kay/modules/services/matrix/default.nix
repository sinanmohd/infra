{ config, ... }:
let
  domain = config.global.userdata.domain;
in
{
  imports = [
    ./dendrite.nix
    ./matrix-sliding-sync.nix
  ];

  sops.secrets."matrix-${domain}/sliding_sync".sopsFile = ./secrets.yaml;

  services.matrix-sliding-sync-dirty = {
    enable = true;
    environmentFile = config.sops.secrets."matrix-${domain}/sliding_sync".path;

    settings = {
      SYNCV3_LOG_LEVEL = "warn";
      SYNCV3_SERVER = "http://127.0.0.1:${toString config.services.dendrite.httpPort}";
    };
  };
}
