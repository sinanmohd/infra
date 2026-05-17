{
  config,
  pkgs,
  ...
}:
let
  user = config.global.userdata.name;
in
{
  imports = [
    ./modules/getty.nix
    ./modules/network.nix
    ./modules/wayland.nix
    ./modules/nopolkit.nix
    ./modules/work.nix
    ./modules/tailscale
  ];
  home-manager.users.${user}.imports = [
    ../../../home/modules/common
    ../../../home/modules/pc
    ../../../home/modules/wayland
  ];

  boot = {
    consoleLogLevel = 3;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  documentation.dev.enable = true;
  environment.systemPackages = [ pkgs.android-tools ];
  users.users.${user}.extraGroups = [ "adbusers" ];
}
