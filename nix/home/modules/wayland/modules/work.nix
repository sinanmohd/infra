{
  config,
  pkgs,
  lib,
  inputsSinan,
  ...
}:
let
  pkgsSinan = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system};
  slack = pkgsSinan.slack.override {
    policies.DownloadPath = config.xdg.userDirs.download;
  };

  messageWork = [
    "󰃖  Ready for Your Workday?"
    "Your team is online and may be waiting to hear from you. Click to open Slack."
  ];
  messageGrass = [
    "󰽥  Time to Unwind"
    "Work can wait until tomorrow. Consider stepping outside. Click to close Slack."
  ];

  slack_nag = pkgs.writeShellApplication {
    name = "slack-nag";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.procps
      pkgs.libnotify
      pkgs.systemd
      config.services.mako.package
    ];

    text = ''
      id_file="''${XDG_RUNTIME_DIR:?}/slack-nag.id"
      state_current=""
      waiter=""
      poll_rate=60

      slack_running() {
        pgrep --exact slack > /dev/null
      }

      slack_open() {
        systemd-run --user --collect --quiet -- ${lib.getExe slack}
      }

      slack_close() {
        pkill --exact slack || :
      }

      is_work_hours() {
        day="$(date +%u)"
        now="$(date +%H%M)"
        # NOTE: Monday to Friday, 11:00 to 19:00
        [ "$day" -le 5 ] && [ "$now" -ge 1100 ] && [ "$now" -lt 1900 ]
      }

      notification_isalive() {
        [ -n "$waiter" ] && kill -0 "$waiter" 2> /dev/null
      }

      # NOTE: usage: notification_start <on click> <summary> <body>
      # notify-send stays alive until the notification is closed, printing
      # the id first and "default" on close when it was clicked, so the
      # background job also tells whether it is still on screen
      notification_start() {
        (
          notify-send --print-id --expire-time=0 \
            --app-name="Work-Life Balance" \
            --action=default=Slack "$2" "$3" | {
            id=""
            action=""
            read -r id || :
            printf '%s\n' "$id" > "$id_file"
            read -r action || :

            if [ "$action" = default ]; then
              "$1"
            fi
          }
        ) &
        waiter=$!
      }

      notification_stop() {
        if notification_isalive; then
          id="$(head -n 1 "$id_file" 2> /dev/null)" || :
          rm -f "$id_file"
          if [ -n "$id" ]; then
            makoctl dismiss -n "$id" || :
          fi
        fi

        waiter=""
      }

      while :; do
        state_want=""
        if is_work_hours; then
          slack_running || state_want=work
        elif slack_running; then
          state_want=grass
        fi

        # NOTE: drop the old notification on any state change,
        # including to no state, so a stale one is not left on screen
        if [ "$state_want" != "$state_current" ]; then
          notification_stop
          state_current="$state_want"
        fi

        # NOTE: start notify
        if ! notification_isalive; then
          case "$state_current" in
          work)
            notification_start slack_open ${lib.escapeShellArgs messageWork}
            ;;
          grass)
            notification_start slack_close ${lib.escapeShellArgs messageGrass}
            ;;
          esac
        fi

        sleep "$poll_rate"
      done
    '';
  };
in
{
  home.packages = [ slack ];

  systemd.user.services.slack-nag = {
    Unit = {
      Description = "Nag about slack in and out of work hours";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe slack_nag;
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
