{
  config,
  ...
}:
let
  fontPackages = with config.global.font; monospace.packages ++ sans.packages ++ emoji.packages;
  fontMonospace = config.global.font.monospace.name;
  fontSans = config.global.font.sans.name;
  fontEmoji = config.global.font.emoji.name;
in
{
  home.packages = fontPackages;

  fonts.fontconfig = {
    enable = true;
    antialiasing = true;
    hinting = "full";
    subpixelRendering = "rgb";

    defaultFonts = {
      monospace = [
        fontMonospace
        fontEmoji
      ];
      serif = [
        fontSans
        fontEmoji
      ];
      sansSerif = [
        fontSans
        fontEmoji
      ];
      emoji = [ fontEmoji ];
    };
  };
}
