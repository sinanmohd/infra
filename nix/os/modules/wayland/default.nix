{
  config,
  ...
}:
let
  user = config.global.userdata.name;
in
{
  imports = [
    ./modules/sway.nix
    ./modules/wayland.nix
    ./modules/work.nix
  ];
  home-manager.users.${user}.imports = [
    ../../../home/modules/common
    ../../../home/modules/pc
    ../../../home/modules/wayland
  ];
}
