{ pkgs, ... }:
{
  imports = [
    ./modules/vaultwarden.nix
    ./modules/k8s
    ../../../global/modules/common
  ];

  home.packages = with pkgs; [
    ffmpeg
    mosh
    deploy-rs
  ];
}
