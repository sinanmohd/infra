{ ... }:
{
  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      # text
      "application/javascript" = "nvim.desktop";
      "text/vnd.trolltech.linguist" = "nvim.desktop";
      "application/json" = "nvim.desktop";
      "application/sql" = "nvim.desktop";
      "application/xml" = "nvim.desktop";
      "text/css" = "nvim.desktop";
      "text/csv" = "nvim.desktop";
      "text/html" = "nvim.desktop";
      "text/markdown" = "nvim.desktop";
      "text/plain" = "nvim.desktop";
      "text/x-c" = "nvim.desktop";
      "text/x-diff" = "nvim.desktop";
      "text/x-lua" = "nvim.desktop";
      "text/x-meson" = "nvim.desktop";
      "text/x-go" = "nvim.desktop";
      "text/xml" = "nvim.desktop";
      "text/x-patch" = "nvim.desktop";
      "text/x-script.python" = "nvim.desktop";
      "text/x-shellscript" = "nvim.desktop";
      "text/x-python" = "nvim.desktop";

      # misc
      "inode/directory" = "yazi.desktop";
    };
  };
}
