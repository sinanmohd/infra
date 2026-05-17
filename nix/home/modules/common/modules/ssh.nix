{ config, ... }:
let
  domain = config.global.userdata.domain;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*".compression = true;
      "kay".hostname = domain;
      "exy" = {
        port = 8022;
        user = "u0_a369";
      };
    };
  };
}
