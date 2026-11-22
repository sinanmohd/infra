{ pkgs, inputsSinan, ... }:
let
  wayland-scripts = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.wayland-scripts;
in
{
  programs.swayimg = {
    enable = true;
    initLua = ''
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
