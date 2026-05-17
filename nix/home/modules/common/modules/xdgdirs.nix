{ config, ... }:
let
  home = config.home.homeDirectory;

  etc = home + "/etc";
  dl = home + "/dl";
in
{
  xdg = {
    enable = true;

    userDirs = {
      enable = true;

      download = dl;
      desktop = etc;
      templates = etc;
      publicShare = dl;
      music = home + "/ms";
      videos = home + "/vid";
      pictures = home + "/pix";
      documents = home + "/doc";
    };
  };
}
