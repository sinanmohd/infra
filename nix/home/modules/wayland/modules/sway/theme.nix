{ pkgs, ... }:
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
in
{
  dconf.enable = false;

  gtk = {
    enable = true;

    gtk3 = {
      extraConfig.gtk-application-prefer-dark-theme = 1;
      extraCss = squareCsd;
    };
    gtk4.extraCss = squareCsd;
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;

    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };
}
