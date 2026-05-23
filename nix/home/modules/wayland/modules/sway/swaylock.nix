{ config, pkgs, ... }:
let
  background = "${config.xdg.dataHome}/wayland/desktop";
  fontSans = config.global.font.sans.name;
in
{

  programs.wallust.settings.templates.swaylock = {
    template = pkgs.writeText "swaylock.conf" ''
      clock
      daemonize
      image=${background}
      indicator-idle-visible
      timestr=%H:%M
      datestr= %a,%e %b
      font=${fontSans}

      color={{background}}
      bs-hl-color={{foreground}}
      key-hl-color={{foreground}}

      layout-bg-color=#00000000
      layout-border-color=#00000000
      layout-text-color={{foreground}}

      caps-lock-bs-hl-color={{foreground}}
      caps-lock-key-hl-color={{foreground}}

      line-color=#00000000
      separator-color=#00000000
      inside-color={{background}}
      ring-color={{background | lighten(0.2)}}
      text-color={{foreground}}

      line-ver-color=#00000000
      inside-ver-color={{background}}
      ring-ver-color={{background | lighten(0.2)}}
      text-ver-color={{foreground}}

      line-caps-lock-color=#00000000
      inside-caps-lock-color={{background}}
      ring-caps-lock-color={{background | lighten(0.2)}}
      text-caps-lock-color={{foreground}}

      line-clear-color=#00000000
      inside-clear-color={{background}}
      ring-clear-color={{background | lighten(0.2)}}
      text-clear-color={{foreground}}

      line-wrong-color=#00000000
      ring-wrong-color=#eba0ac
      text-wrong-color=#eba0ac
      inside-wrong-color={{background}}
    '';
    target = "~/.config/swaylock/config";
  };

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
  };
}
