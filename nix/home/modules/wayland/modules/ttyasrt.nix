{ pkgs, ... }:
let
  wayland-scripts = pkgs.callPackage ../pkgs/wayland-scripts { };
  ttyasrt = "${wayland-scripts}/bin/ttyasrt";
in
{
  home.packages = [ wayland-scripts ];

  xdg.desktopEntries = {
    "yazi".settings = {
      Type = "Application";
      Name = "yazi";
      Comment = "Terminal file manager";
      TryExec = "yazi";
      Exec = "${ttyasrt} yazi";
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
