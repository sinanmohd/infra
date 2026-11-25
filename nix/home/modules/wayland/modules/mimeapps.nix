{ ... }:
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # image
      "image/avif" = "swayimg.desktop";
      "image/gif" = "swayimg.desktop";
      "image/heic" = "swayimg.desktop";
      "image/heif" = "swayimg.desktop";
      "image/jpeg" = "swayimg.desktop";
      "image/png" = "swayimg.desktop";
      "image/svg+xml" = "swayimg.desktop";
      "image/webp" = "swayimg.desktop";
      "image/x-jxl" = "swayimg.desktop";

      # media
      "audio/basic" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/matroska" = "mpv.desktop";
      "audio/x-opus+ogg" = "mpv.desktop";

      # browser
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";

      # apps
      "x-scheme-handler/slack" = "slack.desktop";

      # documents
      "application/pdf" = "org.pwmt.zathura.desktop";
    };
  };
}
