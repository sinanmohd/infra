{ pkgs, ... }:
{
  home.packages = [ pkgs.p7zip ];

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;

    settings.mgr = {
      ratio = [
        0
        1
        1
      ];
      linemode = "size";
    };
  };
}
