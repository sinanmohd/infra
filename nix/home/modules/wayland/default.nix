{ pkgs, ... }:
let
  wayland-scripts = pkgs.callPackage ./pkgs/wayland-scripts { };
in
{
  imports = [
    ./modules/alacritty.nix
    ./modules/mango.nix
    ./modules/portal.nix
    ./modules/zathura.nix
    ./modules/firefox.nix
    ./modules/mimeapps.nix
    ./modules/ttyasrt.nix
    ./modules/sway
    ./modules/waybar
    ./modules/wallust.nix
    ./modules/mako.nix
    ./modules/mpv.nix
    ./modules/fuzzel
    ./modules/element.nix
  ];

  home = {
    sessionVariables.NIXOS_OZONE_WL = 1;

    packages = with pkgs; [
      wtype
      grim
      slurp
      xdg-utils

      mpv
      imv
      gimp3
    ];
  };

  programs.rbw.settings.pinentry = wayland-scripts;
  services.awww.enable = true;
}
