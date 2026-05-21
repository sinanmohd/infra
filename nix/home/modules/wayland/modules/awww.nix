{ pkgs, lib, ... }:
{
  services.swww = {
    enable = true;
    package = pkgs.awww;
  };
  systemd.user.services.swww.Service.ExecStart = lib.mkForce "${pkgs.awww}/bin/awww-daemon";
}
