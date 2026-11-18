{ pkgs, lib, ... }:
let
  # NOTE: SD_MESSAGE_COREDUMP, the id systemd gives every "process dumped core"
  # journal entry. same on every machine
  coredump_message_id = "fc2e22bc6ee647b6b90729ab34a250b1";

  crash_notify = pkgs.writeShellApplication {
    name = "crash-notify";

    runtimeInputs = with pkgs; [
      systemd
      jq
      libnotify
    ];

    text = ''
      journalctl --follow --lines=0 --output=json \
        MESSAGE_ID=${coredump_message_id} |
        jq --unbuffered -r '
          "\(.COREDUMP_COMM // "unknown") (\(.COREDUMP_SIGNAL_NAME // "crash"))"
        ' |
        while read -r program; do
          notify-send --urgency=critical "  Application crashed" "$program" || :
        done
    '';
  };
in
{
  systemd.user.services.crash-notify = {
    Unit = {
      Description = "Notify when an application crashes";
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
