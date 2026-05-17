{ config, pkgs, ... }:
let
  user = config.global.userdata.name;
in
{
  security.sudo = {
    enable = true;

    extraRules = [
      {
        commands = [
          {
            command = "${pkgs.systemd}/bin/systemctl suspend-then-hibernate";
            options = [
              "SETENV"
              "NOPASSWD"
            ];
          }
          {
            command = "${pkgs.systemd}/bin/reboot";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/poweroff";
            options = [ "NOPASSWD" ];
          }
        ];

        users = [ user ];
      }
    ];
  };
}
