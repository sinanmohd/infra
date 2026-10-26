{ config, ... }:
let
  user = config.global.userdata.name;
in
{
  imports = [
    ../../../global/hosts/cez

    ../../modules/common
    ../../modules/pc
    ../../modules/wayland

    ./modules/tlp.nix
    ./modules/lanzaboote.nix
    ./modules/zram.nix
    ./modules/nvidia.nix

    ./disko.nix
  ];
  home-manager.users.${user}.imports = [
    ../../../home/hosts/cez
  ];

  networking.hostName = "cez";

  hardware.facter = {
    reportPath = ./facter.json;
    # uses dhcpcd but we use networkd
    detected.dhcp.enable = false;
  };

  # NOTE: wifi latency spikes, disable power saving
  boot.extraModprobeConfig = ''
    options rtw88_core disable_lps_deep=y
    options rtw88_pci disable_aspm=y
  '';
  services.tlp.settings = {
    WIFI_PWR_ON_AC = "off";
    WIFI_PWR_ON_BAT = "off";
  };
}
