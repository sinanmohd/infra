{
  config,
  lib,
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

  # kde connect
  networking.firewall = rec {
    enable = lib.mkForce false;
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };
}
