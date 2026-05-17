{ pkgs, ... }:
{
  systemd.user.services.waybar.Service.Environment = "PATH=${
    pkgs.wttrbar.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [ ./0001-fix-align-toolbar-text.patch ];
    })
  }/bin";

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = builtins.readFile ./style.css;
    settings.master = builtins.fromJSON (builtins.readFile ./config.json);
  };
}
