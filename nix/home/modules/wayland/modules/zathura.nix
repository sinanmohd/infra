{ config, lib, ... }:
let
  font =
    config.global.font.sans.name
    + lib.optionalString (config.global.font.sans.size != null) " "
    + builtins.toString config.global.font.sans.size;
in
{
  programs.zathura = {
    enable = true;

    mappings = {
      "f" = "toggle_fullscreen";
      "[fullscreen] f" = "toggle_fullscreen";
    };
    options = {
      inherit font;
      statusbar-basename = true;
      selection-clipboard = "clipboard";
      database = "sqlite";
    };
  };
}
