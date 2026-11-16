{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;

    config.common = {
      default = "gtk";
      "org.freedesktop.impl.portal.ScreenCast" = "wlr";
      "org.freedesktop.impl.portal.Screenshot" = "wlr";
      "org.freedesktop.impl.portal.RemoteDesktop" = "luminous";
    };

    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
      xdg-desktop-portal-luminous
    ];
  };
}
