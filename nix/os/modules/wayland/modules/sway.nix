{
  pkgs,
  ...
}:
{
  systemd.services.swaynag_battery = {
    path = [
      pkgs.sway
      pkgs.systemd
    ];
    environment = {
      # TODO: don't hardcode them
      WAYLAND_DISPLAY = "wayland-1";
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
    script = ''
      swaynag \
          -m '󰂃  Critical battery level, system hibernation imminent, please connect to a power source' \
          --layer  overlay \
          --dismiss-button  'Hibernate now' &&
      systemctl hibernate
    '';
  };
  services.udev.extraRules =
    let
      start = "${pkgs.systemd}/bin/systemctl start swaynag_battery";
      stop = "${pkgs.systemd}/bin/systemctl stop swaynag_battery";
    in
    ''
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-9]", RUN+="${start}"
      SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="${stop}"
      SUBSYSTEM=="power_supply", ATTR{status}=="Charging", RUN+="${stop}"
    '';

  security.pam.services.swaylock = { };
}
