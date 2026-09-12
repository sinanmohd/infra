{
  config,
  ...
}:
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
            command = "/run/current-system/sw/bin/systemctl suspend-then-hibernate";
            options = [
              "SETENV"
              "NOPASSWD"
            ];
          }
          {
            command = "/run/current-system/sw/bin/reboot";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/poweroff";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/powertop";
            options = [ "NOPASSWD" ];
          }
        ];

        users = [ user ];
      }
    ];
  };
}
