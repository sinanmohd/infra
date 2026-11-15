{ ... }:
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # image
      "image/avif" = "imv.desktop";
      "image/gif" = "mpv.desktop";
      "image/heic" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/png" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/x-jxl" = "imv.desktop";

      # media
      "audio/basic" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "audio/x-opus+ogg" = "mpv.desktop";

      # browser
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";

      # documents
      "application/pdf" = "org.pwmt.zathura.desktop";
    };
  };
}
