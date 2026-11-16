{ ... }:
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # image
      "image/avif" = "imv-dir.desktop";
      "image/gif" = "mpv.desktop";
      "image/heic" = "imv-dir.desktop";
      "image/heif" = "imv-dir.desktop";
      "image/jpeg" = "imv-dir.desktop";
      "image/png" = "imv-dir.desktop";
      "image/svg+xml" = "imv-dir.desktop";
      "image/webp" = "imv-dir.desktop";
      "image/x-jxl" = "imv-dir.desktop";

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
