{ pkgs, lib, ... }:
let
  mpris = pkgs.mpvScripts.mpris.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace mpris.c \
        --replace-fail '"org.mpris.MediaPlayer2.mpv"' '"org.mpris.MediaPlayer2.speak"'
    '';
  });
  mpv = pkgs.mpv.override { scripts = [ mpris ]; };
in
{
  # NOTE: player behind `speak` from wayland-scripts. speak appends
  # piper output to this mpv's playlist over IPC, and the mpris script lets
  # playerctl (and the media keys) play, pause, skip and stop it

  # NOTE: not RuntimeDirectory=, which removes the dir on
  # stop and leaves sandboxes holding a bind to the deleted one
  systemd.user.tmpfiles.rules = [ "d %t/speak 0700 - - -" ];
  systemd.user.services.speak = {
    Unit.Description = "mpv player for speak";
    Service = {
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe mpv)
        "--no-config"
        "--idle=yes"
        "--no-video"
        "--no-terminal"
        # NOTE: [AGENT]: mpris Identity and the pipewire stream name
        "--audio-client-name=Speak"
        "--input-ipc-server=%t/speak/mpv.sock"
      ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
