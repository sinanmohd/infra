{ pkgs, inputs, ... }:
let
  claude-code = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
in
{
  imports = [
    ./modules/vaultwarden.nix
    ./modules/podman.nix
    ./modules/k8s
    ../../../global/modules/common
  ];

  home.packages = with pkgs; [
    ffmpeg
    mosh
    deploy-rs
    claude-code
  ];
}
