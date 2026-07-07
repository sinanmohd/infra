{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.sbctl
  ];

  boot.loader.systemd-boot.enable = false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
