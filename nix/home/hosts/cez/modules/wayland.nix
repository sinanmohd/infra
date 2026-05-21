{ pkgs, ... }:
let
  wayland-scripts = pkgs.callPackage ../../../modules/wayland/pkgs/wayland-scripts { };
  freezshot = "${wayland-scripts}/bin/freezshot";
  scale = 1.6;

  laptop_screen_y = 2560;
  monitor_position_y = (1 / scale) * laptop_screen_y;
in
{
  wayland.windowManager.sway.settings = {
    # vendor hardcoded screenshot key
    bindsym."mod4+shift+s" = "exec ${freezshot}";

    output = {
      "eDP-1" = {
        inherit scale;
        position = "0 0";
      };
      "HDMI-A-1" = {
        inherit scale;
        position = "${builtins.toString (builtins.ceil monitor_position_y)} 0";
      };
    };
  };
}
