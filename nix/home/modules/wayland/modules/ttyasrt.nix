{
  lib,
  pkgs,
  inputsSinan,
  ...
}:
let
  wayland-scripts = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.wayland-scripts;
  ttyasrt = "${wayland-scripts}/bin/ttyasrt";

  # NOTE: : kdeconnect opens kdeconnect://<device>/<path> urls, which only kio
  # file managers understand, so map them onto its sshfs mount
  yazi-open = pkgs.writeShellApplication {
    name = "yazi-open";
    runtimeInputs = [
      pkgs.trurl
      wayland-scripts
    ];

    text = ''
      case "''${1:-}" in
      kdeconnect://*)
        set -- "$XDG_RUNTIME_DIR/$(trurl --url "$1" --get '{host}{path}')"
        ;;
      file://*)
        set -- "$(trurl --url "$1" --get '{path}')"
        ;;
      esac

      exec ttyasrt yazi "$@"
    '';
  };
in
{
  home.packages = [ wayland-scripts ];

  xdg.desktopEntries = {
    "yazi".settings = {
      Type = "Application";
      Name = "yazi";
      Comment = "Terminal file manager";
      TryExec = "yazi";
      Exec = "${lib.getExe yazi-open} %u";
      # NOTE: pass kdeconnect:// urls to yazi-open instead of kioexec temp files
      X-KDE-Protocols = "file,kdeconnect";
      Icon = "yazi";
      MimeType = "inode/directory";
      Categories = "System;FileTools;FileManager";
      Keywords = "File;Manager;Management;Explorer;Launcher";
    };

    "nvim".settings = {
      Name = "Neovim wrapper";
      GenericName = "Text Editor";
      Comment = "Edit text files";
      TryExec = "nvim";
      Exec = "${ttyasrt} nvim %F";
      Type = "Application";
      Keywords = "Text;editor;";
      Icon = "nvim";
      Categories = "Utility;TextEditor;";
      StartupNotify = "false";
      MimeType = "text/plain";
    };
  };
}
