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
      config.global.font.sans.sizePx != null
    ) " ${lib.toString config.global.font.sans.sizePx}px";
in
{
  home.packages = with pkgs; [ libnotify ];
  services.mako.enable = true;

  programs.wallust.settings = {
    hooks.mako = "makoctl  reload";
    templates.mako = {
      template = pkgs.writeText "mako.conf" ''
        background-color={{background}}
        text-color={{foreground}}
        border-color={{foreground}}
        progress-color=source {{foreground}}
        border-size=2
        default-timeout=3000
        font=${font}
      '';
      target = "~/.config/mako/config";
    };
  };
}
