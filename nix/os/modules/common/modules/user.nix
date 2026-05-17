{ config, ... }:
let
  user = config.global.userdata.name;
  email = config.global.userdata.email;
in
{
  users.users.${user} = {
    uid = 1000;
    isNormalUser = true;
    description = email;
    extraGroups = [ "wheel" ];

    initialHashedPassword = "$y$j9T$5yekb7UNR3e1bHrPLqH/F.$zVIIDLBY4snxLQcdGCb1aHD2rIhs96fvdvPdNkstFcD";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJnqxnFFvG1R/ZfP9GjRem3V9GfSK5pM1uEmsQZrMGWX sinan@exy"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL8LnyOuPmtKRqAZeHueNN4kfYvpRQVwCivSTq+SZvDU sinan@cez"
    ];
  };
}
