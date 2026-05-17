{ config, lib, ... }:
let
  background = "#000000";
  foreground = "#FFFFFF";
  swayYellow = "#d79921";

  font =
    config.global.font.sans.name
    + lib.optionalString (config.global.font.sans.size != null) " "
    + builtins.toString config.global.font.sans.size;
in
{
  programs.bemenu = {
    enable = true;

    settings = {
      fn = font;
      hp = 6;

      tf = swayYellow;
      hf = swayYellow;

      nf = foreground;
      af = foreground;

      nb = background;
      cf = background;
      tb = background;
      fb = background;
      hb = background;
      ab = background;
    };
  };
}
