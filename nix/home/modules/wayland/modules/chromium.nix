{ pkgs, inputsSinan, ... }:
let
  chromium = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.chromium;
in
{
  programs.chromium = {
    enable = true;
    package = chromium;
    commandLineArgs = [
      "--password-store=gnome-libsecret"
      "--remote-debugging-port=9222"
    ];
  };
}
