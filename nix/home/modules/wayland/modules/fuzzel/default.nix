{
  config,
  pkgs,
  lib,
  ...
}:
let
  font =
    config.global.font.sans.name
    + lib.optionalString (
      config.global.font.sans.size != null
    ) ":pixelsize=${lib.toString config.global.font.sans.size}";
in
{
  home.sessionVariables.TERMINAL = lib.getExe config.programs.alacritty.package;
  programs.fuzzel = {
    enable = true;
    package = pkgs.fuzzel.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        ./0001-config-add-colors.cursor-and-cursor-color-option.patch
      ];
    });
  };

  programs.wallust.settings.templates.fuzzel = {
    template = pkgs.writeText "fuzzel.toml" ''
      font=${font}
      horizontal-pad=10
      prompt=""
      list-executables-in-path=true
      icons-enabled=false
      [border]
      radius=0
      width=2
      [colors]
      background={{background}}{{alpha | alpha_hexa}}
      cursor={{background}}{{alpha | alpha_hexa}}
      selection-text={{background}}{{alpha | alpha_hexa}}
      text={{foreground}}{{alpha | alpha_hexa}}
      input={{foreground}}{{alpha | alpha_hexa}}
      border={{foreground}}{{alpha | alpha_hexa}}
      prompt={{foreground}}{{alpha | alpha_hexa}}
      match={{color10}}{{alpha | alpha_hexa}}
      selection-match={{background}}{{alpha | alpha_hexa}}
    '';
    target = "~/.config/fuzzel/fuzzel.ini";
  };
}
