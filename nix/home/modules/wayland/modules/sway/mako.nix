{
  config,
  pkgs,
  lib,
  ...
}:
let
  font =
    config.global.font.sans.name
    + lib.optionalString (config.global.font.sans.size != null) " "
    + builtins.toString config.global.font.sans.size;
in
{
  home.packages = with pkgs; [ libnotify ];

  services.mako = {
    enable = true;
    settings = {
      inherit font;
      default-timeout = 3000;
      border-size = 3;
      background-color = "#000000";
    };
  };
}
