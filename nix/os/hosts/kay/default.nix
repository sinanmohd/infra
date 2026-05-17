{ config, ... }:
let
  user = config.global.userdata.name;
in
{
  imports = [
    ../../modules/server
    ../../modules/common

    ./hardware-configuration.nix

    ./modules/dns
    ./modules/network/ppp
    ./modules/network/headscale
    ./modules/network/hurricane
    ./modules/network/router.nix

    ./modules/observability

    ./modules/internal/www.nix
    ./modules/internal/acme.nix
    ./modules/internal/postgresql.nix
    ./modules/internal/k3s

    ./modules/services/sftp.nix
    ./modules/services/mail
    ./modules/services/home-assistant.nix
    ./modules/services/nix-cache
    ./modules/services/immich.nix
    ./modules/services/matrix
    ./modules/services/vaultwarden
  ];
  home-manager.users.${user}.imports = [
    ../../../home/modules/common
  ];

  networking.hostName = "kay";

  boot = {
    consoleLogLevel = 3;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
  };
}
