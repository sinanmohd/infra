{
  config,
  lib,
  pkgs,
  inputsSinan,
  ...
}:
let
  wayland-scripts = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.wayland-scripts;
  fontName = config.global.font.sans.name;
  fontSize = config.global.font.sans.sizePx;
in
{
  programs.swayimg = {
    enable = true;
    initLua = ''
      swayimg.overlay = false
      swayimg.imagelist.adjacent = true
      swayimg.text.visible = false
      swayimg.text.timeout = 0
      swayimg.text.font = "${fontName}"
      ${lib.optionalString (fontSize != null) ''
        swayimg.text.size = ${lib.toString fontSize}
      ''}

      local function set_wallpaper(img)
        if img then
          os.execute(string.format("${wayland-scripts}/bin/cwall %q &", img.path))
        end
      end

      swayimg.viewer.on_key({ "Ctrl+w", "Ctrl-w" }, function()
        set_wallpaper(swayimg.viewer.get_image())
      end)

      swayimg.gallery.on_key({ "Ctrl+w", "Ctrl-w" }, function()
        set_wallpaper(swayimg.gallery.get_image())
      end)

      swayimg.slideshow.on_key({ "Ctrl+w", "Ctrl-w" }, function()
        set_wallpaper(swayimg.slideshow.get_image())
      end)
    '';
  };
}
