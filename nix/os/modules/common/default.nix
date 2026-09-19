{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  user = config.global.userdata.name;
in
{
  disabledModules = [
    "services/networking/pppd.nix"
  ];
  imports = [
    ../../../global/modules/common

    ./modules/nix.nix
    ./modules/user.nix
    ./modules/shell.nix
    ./modules/pppd.nix
    ./modules/network.nix
  ];

  home-manager.users.${user}.imports = [
    ../../../home/modules/common
  ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };
  # required by installed Home Manager via its NixOS module + useUserPackages = true
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  system.stateVersion = "26.05";
  time.timeZone = "Asia/Kolkata";
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  programs.nix-index-database.comma.enable = true;

  zramSwap.enable = true;
  swapDevices = lib.mkDefault [
    {
      device = "/swapfile";
      size = 2048; # 2GB
    }
  ];

  boot = {
    loader.timeout = 0;
    initrd.systemd.enable = true;
    tmp.cleanOnBoot = true;
  };

  services.udev.extraRules =
    let
      cmd = "${pkgs.systemd}/bin/systemctl hibernate";
    in
    ''
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="${cmd}"
    '';
}
