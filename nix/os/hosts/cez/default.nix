{ config, ... }:
let
  user = config.global.userdata.name;
in
{
  imports = [
    ../../../global/hosts/cez

    ../../modules/pc
    ../../modules/common

    ./modules/tlp.nix
    ./hardware-configuration.nix
  ];
  home-manager.users.${user}.imports = [
    ../../../home/hosts/cez
  ];

  networking.hostName = "cez";
}
