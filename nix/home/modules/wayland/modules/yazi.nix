{ pkgs, inputsSinan, ... }:
let
  wayland-scripts = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.wayland-scripts;
in
{
  programs.yazi.keymap.mgr.prepend_keymap = [
    {
      on = "<C-w>";
      run = "shell -- ${wayland-scripts}/bin/cwall %h";
      desc = "Set the hovered file as wallpaper";
    }
  ];
}
