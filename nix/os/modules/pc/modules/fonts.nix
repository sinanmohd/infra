{
  config,
  ...
}:
let
  fontPackages = config.global.font.monospace.packages ++ config.global.font.sans.packages;
  fontMonospace = config.global.font.monospace.name;
  fontSans = config.global.font.sans.name;
in
{
  fonts = {
    packages = fontPackages;
    enableDefaultPackages = true;

    fontconfig = {
      antialias = true;
      hinting.style = "full";
      subpixel.rgba = "rgb";

      defaultFonts = {
        monospace = [ fontMonospace ];
        serif = [ fontSans ];
        sansSerif = [ fontSans ];
      };
    };
  };
}
