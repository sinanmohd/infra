{ config, ... }:
let
  user = config.global.userdata.name;
in
{
  systemd.services."getty@".serviceConfig.TTYVTDisallocate = "no";

  services.getty = {
    loginOptions = "-f ${user}";
    extraArgs = [
      "--nonewline"
      "--skip-login"
      "--noclear"
      "--noissue"
    ];
  };
}
