{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [ libnotify ];

  programs.wallust.settings.templates.mpv = {
    template = pkgs.writeText "mpv.conf" ''
      hwdec=auto-safe
      vo=dmabuf-wayland
      cache
      audio-channels=auto-safe

      slang=en
      alang=en
      subs-fallback=yes
      subs-with-matching-audio=yes
      save-position-on-quit
      keepaspect-window=no
      ytdl-format="bestvideo[height<=2400]+bestaudio/best"

      sub-border-size=1
      osd-border-size=1

      sub-color='{{foreground}}'
      sub-outline-color='{{background}}'
      osd-color='{{foreground}}'
      osd-outline-color='{{background}}'

      screenshot-directory=~/pix/ss
      watch-later-directory=~/.local/share/mpv/watch_later
      sub-file-paths=~/.local/share/mpv/subs

      [extension.gif]
      loop-file=inf

      #[HDR]
      #profile-cond=p["video-params/gamma"] == "pq"
      #profile-restore=copy
      #gamut-mapping-mode=auto
      #hdr-compute-peak=yes
    '';
    target = "~/.config/mpv/mpv.conf";
  };
}
