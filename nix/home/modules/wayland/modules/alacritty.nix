{
  config,
  pkgs,
  lib,
  ...
}:
let
  size = config.global.font.monospace.sizePx;
in
{
  home.sessionVariables.TERMINAL = lib.getExe config.programs.alacritty.package;

  programs.wallust.settings.templates.alacritty = {
    template = pkgs.writeText "alacritty.toml" ''
      # mixed with static colors from dracula: https://github.com/dracula/alacritty/blob/master/dracula.toml

      [colors.primary]
      background="{{background}}"
      foreground = "{{foreground}}"
      dim_foreground = "{{foreground | darken(0.4)}}"
      bright_foreground = "{{foreground | lighten(0.2)}}"

      [colors.cursor]
      text = "{{background}}"
      cursor = "{{foreground}}"

      [colors.vi_mode_cursor]
      text = "CellBackground"
      cursor = "CellForeground"

      [colors.selection]
      text = "{{background}}"
      background = "{{foreground}}"

      [colors.normal]
      black = "{{background}}"
      red = "#ff5555"
      green = "#50fa7b"
      yellow = "#f1fa8c"
      blue = "#bd93f9"
      magenta = "#ff79c6"
      cyan = "#8be9fd"
      white = "{{foreground}}"

      [colors.bright]
      black = "#6272a4"
      red = "#ff6e6e"
      green = "#69ff94"
      yellow = "#ffffa5"
      blue = "#d6acff"
      magenta = "#ff92df"
      cyan = "#a4ffff"
      white = "{{foreground}}"

      [colors.search.matches]
      foreground = "#44475a"
      background = "#50fa7b"

      [colors.search.focused_match]
      foreground = "#44475a"
      background = "#ffb86c"

      [colors.footer_bar]
      background = "#282a36"
      foreground = "#f8f8f2"

      [colors.hints.start]
      foreground = "#282a36"
      background = "#f1fa8c"

      [colors.hints.end]
      foreground = "#f1fa8c"
      background = "#282a36"
    '';
    target = "~/.local/share/wallust/alacritty.toml";
  };

  programs.alacritty = {
    enable = true;
    package = pkgs.alacritty-graphics;
    settings = {
      general.import = [ "~/.local/share/wallust/alacritty.toml" ];
      font = {
        inherit size;
      };
      window = {
        opacity = 0.8;
        padding = {
          x = 10;
          y = 10;
        };
      };
    };
  };
}
