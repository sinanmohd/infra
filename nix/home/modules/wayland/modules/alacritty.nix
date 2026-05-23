{
  config,
  pkgs,
  lib,
  ...
}:
let
  size = config.global.font.monospace.size;
in
{
  home.sessionVariables.TERMINAL = lib.getExe config.programs.alacritty.package;

  programs.wallust.settings.templates.alacritty = {
    template = pkgs.writeText "alacritty.toml" ''
      # from catppuccin: https://github.com/catppuccin/alacritty/blob/main/catppuccin-mocha.toml
      [colors.primary]
      # background = "#1e1e2e"
      # foreground = "#cdd6f4"
      # dim_foreground = "#7f849c"
      # bright_foreground = "#cdd6f4"
      background="{{background}}"
      foreground = "{{foreground}}"
      dim_foreground = "{{foreground | darken(0.4)}}"
      bright_foreground = "{{foreground | lighten(0.2)}}"

      [colors.cursor]
      text = "#1e1e2e"
      cursor = "#f5e0dc"

      [colors.vi_mode_cursor]
      text = "#1e1e2e"
      cursor = "#b4befe"

      [colors.search.matches]
      foreground = "#1e1e2e"
      background = "#a6adc8"

      [colors.search.focused_match]
      foreground = "#1e1e2e"
      background = "#a6e3a1"

      [colors.footer_bar]
      foreground = "#1e1e2e"
      background = "#a6adc8"

      [colors.hints.start]
      foreground = "#1e1e2e"
      background = "#f9e2af"

      [colors.hints.end]
      foreground = "#1e1e2e"
      background = "#a6adc8"

      [colors.selection]
      text = "#1e1e2e"
      background = "#f5e0dc"

      [colors.normal]
      black = "#45475a"
      red = "#f38ba8"
      green = "#a6e3a1"
      yellow = "#f9e2af"
      blue = "#89b4fa"
      magenta = "#f5c2e7"
      cyan = "#94e2d5"
      white = "#bac2de"

      [colors.bright]
      black = "#585b70"
      red = "#f38ba8"
      green = "#a6e3a1"
      yellow = "#f9e2af"
      blue = "#89b4fa"
      magenta = "#f5c2e7"
      cyan = "#94e2d5"
      white = "#a6adc8"

      [[colors.indexed_colors]]
      index = 16
      color = "#fab387"

      [[colors.indexed_colors]]
      index = 17
      color = "#f5e0dc"
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
