{ ... }:
{
  imports = [
    ../../../global/hosts/cez

    ../../modules/common
    ../../modules/pc
    ../../modules/wayland

    ./modules/wayland.nix
  ];
}
