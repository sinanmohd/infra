{
  config,
  lib,
  pkgs,
  ...
}:
let
  swaylock = lib.getExe config.programs.swaylock.package;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  swaymsg = "${pkgs.sway}/bin/swaymsg";

  minute = 60; # seconds
  suspend_timeout = minute * 60;
  suspend_on_battery = pkgs.writeShellApplication {
    name = "suspend_on_battery";
    runtimeInputs = with pkgs; [
      gnugrep
      systemd
      sudo
      coreutils
    ];
    text =
      let
        sudo = "/run/wrappers/bin/sudo";
      in
      ''
              is_discharging() {
        	  grep -qFx \
        	      'POWER_SUPPLY_STATUS=Discharging' \
        	      /sys/class/power_supply/*/uevent
              }

              was_charging=false
              while true; do
        	  if is_discharging; then
        	      if [ $was_charging = true ]; then
        		  sleep ${builtins.toString suspend_timeout}
        	      fi

        	      if is_discharging; then
        		  ${sudo} systemctl suspend-then-hibernate
        	      fi
        	  fi

        	  was_charging=true
        	  sleep 10
              done
      '';
  };
in
{
  systemd.user.services.suspend_on_battery = {
    Unit.Description = "Suspend on battery";
    Service.ExecStart = lib.getExe suspend_on_battery;
  };

  services.swayidle = {
    enable = true;
    systemdTargets = [ "sway-session.target" ];
    events."before-sleep" = swaylock;

    timeouts = [
      {
        timeout = minute * 30;
        command = "${brightnessctl} --save; " + "${brightnessctl} set 10%-";
        resumeCommand = "${brightnessctl} --restore";
      }

      {
        timeout = minute * 31;
        command = swaylock;
      }

      {
        timeout = minute * 32;
        command =
          "${swaymsg} --type command 'output * dpms off'; "
          + "${brightnessctl} -c leds -d platform::kbd_backlight --save; "
          + "${brightnessctl} -c leds -d platform::kbd_backlight set 0";
        resumeCommand =
          "${brightnessctl} -c leds -d platform::kbd_backlight --restore; "
          + "${swaymsg} --type command 'output * dpms on'";
      }

      {
        timeout = suspend_timeout;
        command = "${pkgs.systemd}/bin/systemctl --user start suspend_on_battery";
        resumeCommand = "${pkgs.systemd}/bin/systemctl --user stop suspend_on_battery";
      }
    ];
  };
}
