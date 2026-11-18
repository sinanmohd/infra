{
  config,
  pkgs,
  lib,
  ...
}:
let
  # NOTE: SD_MESSAGE_COREDUMP, the id systemd gives every "process dumped core"
  # journal entry. same on every machine
  coredump_message_id = "fc2e22bc6ee647b6b90729ab34a250b1";

  crash_notify = pkgs.writeShellApplication {
    name = "crash-notify";

    runtimeInputs = [
      pkgs.systemd
      pkgs.jq
      pkgs.libnotify
      pkgs.less
      pkgs.wl-clipboard
      config.programs.alacritty.package
    ];

    text = ''
      # NOTE: [AGENT]: usage: notify <pid> <text>
      # notify-send waits until the notification is closed and prints
      # "default" when it was clicked, so this is run in the background
      notify() {
        action="$(
          notify-send --urgency=critical --expire-time=0 \
            --action=default=Details \
            "  Program crashed" "$2" || :
        )"

        # NOTE: default less flags quit right away when the text fits on one
        # screen
        if [ "$action" = default ]; then
          coredumpctl --no-pager info "$1" | wl-copy || :
          SYSTEMD_LESS=RSMK \
            alacritty --class floater -e coredumpctl info "$1"
        fi
      }

      journalctl --follow --lines=0 --output=json \
        MESSAGE_ID=${coredump_message_id} |
        jq --unbuffered -r '
          "\(.COREDUMP_PID) "
            + "\(.COREDUMP_COMM // "unknown") "
            + "(\(.COREDUMP_SIGNAL_NAME // "crash"))"
        ' |
        while read -r pid program; do
          notify "$pid" "$program" &
        done
    '';
  };
in
{
  systemd.user.services.crash-notify = {
    Unit = {
      Description = "Notify when a program crashes";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe crash_notify;
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
