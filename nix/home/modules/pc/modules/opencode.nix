{ pkgs, inputsSinan, ... }:
let
  opencode = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in
{
  programs.opencode = {
    enable = true;
    package = opencode;
    tui.theme = "system";
  };
}
