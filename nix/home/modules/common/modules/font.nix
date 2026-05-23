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
  home.packages = fontPackages;

  fonts.fontconfig = {
    enable = true;
    antialiasing = true;
    hinting = "full";
    subpixelRendering = "rgb";

    defaultFonts = {
      monospace = [ fontMonospace ];
      serif = [ fontSans ];
      sansSerif = [ fontSans ];
    };
  };
}
