{ config, ... }:
let
  user = config.global.userdata.name;
in
{
  imports = [
    ../../../global/hosts/cez

    ../../modules/common
    ../../modules/pc
    ../../modules/wayland

    ./modules/tlp.nix
    ./modules/lanzaboote.nix
    ./modules/zram.nix

    ./disko.nix
  ];
  home-manager.users.${user}.imports = [
    ../../../home/hosts/cez
  ];

  networking.hostName = "cez";

  hardware.facter = {
    reportPath = ./facter.json;
    # uses dhcpcd but we use networkd
    detected.dhcp.enable = false;
  };
}
