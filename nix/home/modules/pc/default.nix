{ pkgs, inputsSinan, ... }:
let
  claude-code = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
in
{
  imports = [
    ./modules/vaultwarden.nix
    ./modules/podman.nix
    ./modules/k8s
    ./modules/opencode.nix
    ../../../global/modules/common
  ];

  home.packages = with pkgs; [
    ffmpeg
    mosh
    deploy-rs
    claude-code
  ];
}
