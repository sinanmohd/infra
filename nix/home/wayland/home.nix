{ pkgs, ... }:
{
  imports = [
    ../common/home.nix
    ./modules/foot.nix
    ./modules/mango.nix
    ./modules/portal.nix
    ./modules/zathura.nix
    ./modules/firefox.nix
    ./modules/mimeapps.nix
    ./modules/ttyasrt.nix
    ./modules/sway/home.nix
    ./modules/waybar
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
      qemu
      hoppscotch
      element-desktop
      gimp3
    ];
  };
}
