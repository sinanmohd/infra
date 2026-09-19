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
  fonts = {
    packages = fontPackages;
    enableDefaultPackages = true;

    fontconfig = {
      antialias = true;
      hinting.style = "full";
      subpixel.rgba = "rgb";

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
  };
}
