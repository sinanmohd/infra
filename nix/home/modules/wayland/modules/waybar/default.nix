{
  config,
  pkgs,
  lib,
  ...
}:
let

  fontName = config.global.font.sans.name;
  fontSize = config.global.font.sans.size;
in
{
  systemd.user.services.waybar.Service.Environment = "PATH=${
    pkgs.wttrbar.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [ ./0001-fix-align-toolbar-text.patch ];
    })
  }/bin";

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = builtins.readFile ./style.css;
    settings.master = builtins.fromJSON (builtins.readFile ./config.json);
  };

  programs.wallust.settings.templates.waybar = {
    template = pkgs.writeText "waybar.css" ''
      @define-color cursor {{cursor}};
      @define-color background {{background}};
      @define-color foreground {{foreground}};
      @define-color color0  {{color0 }};
      @define-color color1  {{color1 }};
      @define-color color2  {{color2 }};
      @define-color color3  {{color3 }};
      @define-color color4  {{color4 }};
      @define-color color5  {{color5 }};
      @define-color color6  {{color6 }};
      @define-color color7  {{color7 }};
      @define-color color8  {{color8 }};
      @define-color color9  {{color9 }};
      @define-color color10 {{color10}};
      @define-color color11 {{color11}};
      @define-color color12 {{color12}};
      @define-color color13 {{color13}};
      @define-color color14 {{color14}};
      @define-color color15 {{color15}};


      * {
        font-family: '${fontName}';
        ${lib.optionalString (fontSize != null) "font-size: ${lib.toString fontSize}px;"}
      }
    '';
    target = "~/.local/share/wallust/waybar.css";
  };
}
