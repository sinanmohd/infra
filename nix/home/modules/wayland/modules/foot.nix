{ config, lib, ... }:
let
  font =
    config.global.font.monospace.name
    + lib.optionalString (config.global.font.monospace.size != null) ":size="
    + builtins.toString config.global.font.monospace.size;
in
{
  home.sessionVariables.TERMINAL = lib.getExe config.programs.foot.package;
  programs.foot = {
    enable = true;

    settings = {
      colors-dark = {
        background = "000000";
        alpha = "0.8";
      };
      main = {
        inherit font;
        pad = "10x10";
      };
    };
  };
}
