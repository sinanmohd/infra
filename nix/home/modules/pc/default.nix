{ pkgs, ... }:
{
  imports = [
    ./modules/vaultwarden.nix
    ./modules/podman.nix
    ./modules/k8s
    ./modules/agents
    ../../../global/modules/common
  ];

  home.packages = with pkgs; [
    ffmpeg
    mosh
    deploy-rs
  ];
}
