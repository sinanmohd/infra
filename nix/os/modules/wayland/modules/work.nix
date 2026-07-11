{
  pkgs,
  lib,
  ...
}:
{
  programs.firejail = {
    enable = true;
    wrappedBinaries.slack = {
      executable = lib.getExe pkgs.slack;
      profile = "${pkgs.firejail}/etc/firejail/slack.profile";
    };
  };
}
