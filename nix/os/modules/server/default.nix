{ config, ... }:
let
  user = config.global.userdata.name;
in
{
  imports = [
    ../common
  ];
  home-manager.users.${user}.imports = [
    ../../../home/modules/common
  ];

  security.sudo.wheelNeedsPassword = false;
}
