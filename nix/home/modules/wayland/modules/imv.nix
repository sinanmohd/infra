{ pkgs, inputsSinan, ... }:
let
  wayland-scripts = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.wayland-scripts;
in
{
  programs.imv = {
    enable = true;
    settings.binds.w = ''exec ${wayland-scripts}/bin/cwall "$imv_current_file"'';
  };
}
