{
  config,
  pkgs,
  lib,
  ...
}:
let
  # NOTE: remove rounded corners and dropshadow, sway draws the border instead
  # https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
  squareCsd = ''
    /** Some apps use titlebar class and some window */
    .titlebar,
    window {
    	border-radius: 0;
    	box-shadow: none;
    }

    /** also remove shadows */
    decoration {
    	box-shadow: none;
    }

    decoration:backdrop {
    	box-shadow: none;
    }
  '';

  gtkTheme = "wallust";
  gtkThemeAlt = "${gtkTheme}-alt";
  gtkColors = "${config.xdg.dataHome}/wallust/gtk.css";
  qtctColors = "${config.xdg.dataHome}/wallust/qtct.conf";

  # adw-gtk3 with the wallust colors on top. It has to be a real theme, because
  # running GTK apps only reload CSS when the theme name changes.
  adwGtk3 = "${pkgs.adw-gtk3}/share/themes/adw-gtk3-dark";
  mkGtkThemeCss = version: ''
    @import url("file://${adwGtk3}/${version}/gtk.css");
    @import url("file://${gtkColors}");
  '';
in
{
  # two identical themes, switching between them makes running GTK apps
  # (chromium, portal file chooser) reload the colors without flashing another theme
  xdg.dataFile = lib.mergeAttrsList (
    map
      (name: {
        "themes/${name}/gtk-3.0/gtk.css".text = mkGtkThemeCss "gtk-3.0";
        "themes/${name}/gtk-4.0/gtk.css".text = mkGtkThemeCss "gtk-4.0";
      })
      [
        gtkTheme
        gtkThemeAlt
      ]
  );

  programs.wallust.settings.hooks.gtk =
    let
      dconf = lib.getExe pkgs.dconf;
      key = "/org/gnome/desktop/interface/gtk-theme";
      schemeKey = "/org/gnome/desktop/interface/color-scheme";
    in
    ''
      if [ "$(${dconf} read ${key})" = "'${gtkTheme}'" ]; then
        ${dconf} write ${key} "'${gtkThemeAlt}'"
      else
        ${dconf} write ${key} "'${gtkTheme}'"
      fi

      # NOTE: AGENT libadwaita ignores the theme name, but re-reads
      # ~/.config/gtk-4.0/gtk.css when the color scheme changes. Apps read the
      # value after the change signal, so give them time to see 'prefer-light'
      # before switching back
      ${dconf} write ${schemeKey} "'prefer-light'"
      sleep 0.3
      ${dconf} write ${schemeKey} "'prefer-${config.gtk.colorScheme}'"
    '';

  # NOTE: qt5ct/qt6ct reload their settings (and the color scheme) when an entry
  # in their config dir is added or removed, so poke the dirs
  programs.wallust.settings.hooks.qtct =
    lib.concatMapStrings
      (qtct: ''
        touch ${config.xdg.configHome}/${qtct}/.wallust-reload
        rm -f ${config.xdg.configHome}/${qtct}/.wallust-reload
      '')
      [
        "qt5ct"
        "qt6ct"
      ];

  programs.wallust.settings.templates = {
    # NOTE: AGENT: libadwaita named colors, honoured by both adw-gtk3 (GTK 3)
    # and libadwaita (GTK 4)
    # https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/named-colors.html
    gtk = {
      template = pkgs.writeText "gtk.css" ''
        @define-color accent_color {{foreground}};
        @define-color accent_bg_color {{foreground}};
        @define-color accent_fg_color {{background}};

        @define-color window_bg_color {{background}};
        @define-color window_fg_color {{foreground}};
        @define-color view_bg_color {{background}};
        @define-color view_fg_color {{foreground}};

        @define-color headerbar_bg_color {{background | lighten(0.05)}};
        @define-color headerbar_fg_color {{foreground}};
        @define-color headerbar_border_color {{foreground}};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color headerbar_shade_color rgba(0, 0, 0, 0.36);

        @define-color sidebar_bg_color {{background | lighten(0.05)}};
        @define-color sidebar_fg_color {{foreground}};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_shade_color rgba(0, 0, 0, 0.36);
        @define-color secondary_sidebar_bg_color {{background | lighten(0.05)}};
        @define-color secondary_sidebar_fg_color {{foreground}};
        @define-color secondary_sidebar_backdrop_color @window_bg_color;
        @define-color secondary_sidebar_shade_color rgba(0, 0, 0, 0.36);

        @define-color card_bg_color {{background | lighten(0.1)}};
        @define-color card_fg_color {{foreground}};
        @define-color card_shade_color rgba(0, 0, 0, 0.36);

        @define-color dialog_bg_color {{background | lighten(0.05)}};
        @define-color dialog_fg_color {{foreground}};

        @define-color popover_bg_color {{background | lighten(0.05)}};
        @define-color popover_fg_color {{foreground}};
        @define-color popover_shade_color rgba(0, 0, 0, 0.36);

        @define-color thumbnail_bg_color {{background | lighten(0.1)}};
        @define-color thumbnail_fg_color {{foreground}};

        @define-color shade_color rgba(0, 0, 0, 0.36);
        @define-color scrollbar_outline_color rgba(0, 0, 0, 0.5);
      '';
      target = gtkColors;
    };

    # NOTE: AGENT: QPalette color roles, in order:
    # WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText, ButtonText, Base, Window,
    # Shadow, Highlight, HighlightedText, Link, LinkVisited, AlternateBase, NoRole, ToolTipBase,
    # ToolTipText, PlaceholderText
    qtct = {
      template = pkgs.writeText "qtct.conf" ''
        [ColorScheme]
        active_colors={{foreground}}, {{background | lighten(0.1)}}, {{background | lighten(0.3)}}, {{background | lighten(0.2)}}, {{background | darken(0.2)}}, {{background | lighten(0.05)}}, {{foreground}}, {{foreground | lighten(0.2)}}, {{foreground}}, {{background}}, {{background}}, #000000, {{foreground}}, {{background}}, {{foreground}}, {{foreground | darken(0.2)}}, {{background | lighten(0.05)}}, {{background}}, {{background}}, {{foreground}}, {{foreground | darken(0.4)}}
        inactive_colors={{foreground}}, {{background | lighten(0.1)}}, {{background | lighten(0.3)}}, {{background | lighten(0.2)}}, {{background | darken(0.2)}}, {{background | lighten(0.05)}}, {{foreground}}, {{foreground | lighten(0.2)}}, {{foreground}}, {{background}}, {{background}}, #000000, {{foreground | darken(0.2)}}, {{background}}, {{foreground}}, {{foreground | darken(0.2)}}, {{background | lighten(0.05)}}, {{background}}, {{background}}, {{foreground}}, {{foreground | darken(0.4)}}
        disabled_colors={{foreground | darken(0.4)}}, {{background | lighten(0.1)}}, {{background | lighten(0.3)}}, {{background | lighten(0.2)}}, {{background | darken(0.2)}}, {{background | lighten(0.05)}}, {{foreground | darken(0.4)}}, {{foreground | darken(0.4)}}, {{foreground | darken(0.4)}}, {{background}}, {{background}}, #000000, {{background | lighten(0.2)}}, {{foreground | darken(0.4)}}, {{foreground | darken(0.4)}}, {{foreground | darken(0.4)}}, {{background | lighten(0.05)}}, {{background}}, {{background}}, {{foreground | darken(0.4)}}, {{foreground | darken(0.4)}}
      '';
      target = qtctColors;
    };
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
    theme.name = gtkTheme;

    gtk3 = {
      extraCss = squareCsd;
    };
    gtk4 = {
      # NOTE: AGENT: libadwaita ignores the theme name, it only picks up the
      # named colors from user css
      theme = null;
      # NOTE: AGENT: @import has to come before any other rule
      extraCss = ''
        @import url("file://${gtkColors}");

        ${squareCsd}
      '';
    };
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;

    name = "Adwaita";
    size = 24;
    package = pkgs.adwaita-icon-theme;
  };
  wayland.windowManager.sway.settings.seat."*".xcursor_theme =
    with config.home.pointerCursor;
    "${name} ${toString size}";

  home.packages = [ pkgs.kdePackages.breeze-icons ];
  qt =
    let
      # NOTE: without [Fonts] qtct falls back to Qt's built-in 12pt
      mkQtFont =
        font:
        ''"${font.name},${toString (if font.sizePt != null then font.sizePt else 10)},-1,5,50,0,0,0,0,0"'';
      qtctSettings = {
        Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = qtctColors;
          # NOTE: Qt's built-in QFileDialog takes seconds to open, use the portal
          # (gtk) file chooser instead
          standard_dialogs = "xdgdesktopportal";
          # NOTE: unset, Qt apps fall back to plain breeze, dark icons
          # meant for light backgrounds (kdeconnect tray menu)
          icon_theme = "breeze-dark";
        };
        # NOTE: unset, qtct reports ToolButtonFollowStyle and apps like
        # qbittorrent draw (truncated) text beside toolbar icons. 0 = IconOnly,
        # Qt's default without qtct
        Interface.toolbutton_style = 0;
        Fonts = {
          general = mkQtFont config.global.font.sans;
          fixed = mkQtFont config.global.font.monospace;
        };
      };
    in
    {
      enable = true;
      platformTheme.name = "qtct";
      qt5ctSettings = qtctSettings;
      qt6ctSettings = qtctSettings;
    };
}
