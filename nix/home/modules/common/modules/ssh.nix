{ config, ... }:
let
  domain = config.global.userdata.domain;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "Host *".Compression = true;
      "Host kay".HostName = domain;
      "Host exy" = {
        Port = 8022;
        User = "u0_a369";
      };
    };
  };
}
