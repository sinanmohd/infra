{ pkgs, ... }:
{
  dconf.enable = false;

  gtk = {
    enable = true;

    gtk3 = {
      extraConfig.gtk-application-prefer-dark-theme = 1;
      # remove rounded corners and dropshadow
      # https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
      extraCss = ''
        .titlebar,
        window {
                border-radius: 0;
                box-shadow: none;
        }

        decoration {
                box-shadow: none;
        }

        decoration:backdrop {
                box-shadow: none;
        }
      '';
    };
  };

  home.pointerCursor = {
    gtk.enable = true;

    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
  };
}
