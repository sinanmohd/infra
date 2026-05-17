{ config, ... }:
let
  user = config.global.userdata.name;
in
{
  home-manager.users.${user}.imports = [
    ../../../home/modules/common
  ];

  security.sudo.wheelNeedsPassword = false;
}
