{
  config,
  ...
}:
let
  user = config.global.userdata.name;
in
{
  users.users.${user}.extraGroups = [ "seat" ];
  programs.dconf.enable = true;

  services = {
    seatd.enable = true;
    dbus = {
      enable = true;
      implementation = "broker";
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
