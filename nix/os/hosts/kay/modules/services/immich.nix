{ config, ... }:
let
  domain = config.global.userdata.domain;
  mediaLocation = "/hdd/immich";
in
{
  services.immich = {
    enable = true;
    inherit mediaLocation;
    settings.server.externalDomain = "https://immich.${domain}";
  };

  systemd.tmpfiles.settings.immich.${mediaLocation}.d = {
    group = config.services.immich.group;
    user = config.services.immich.user;
    mode = "0755";
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
  ];
}
