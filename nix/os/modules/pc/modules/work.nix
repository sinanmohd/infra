{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = config.global.userdata.name;
in
{
  programs.firejail.wrappedBinaries.slack = {
    executable = lib.getExe pkgs.slack;
    profile = "${pkgs.firejail}/etc/firejail/slack.profile";
  };

  virtualisation.docker.enable = true;
  users.extraGroups.docker.members = [ user ];
}
