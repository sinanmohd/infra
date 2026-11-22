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
  wallustColors = "${config.xdg.dataHome}/wallust/swayimg.lua";
  wl-copy = lib.getExe' pkgs.wl-clipboard "wl-copy";
  gio = lib.getExe' pkgs.glib "gio";
  restoreTrash = pkgs.writeShellScript "swayimg-restore-trash" ''
    target="$1"
    if [ -z "$target" ]; then
      exit 0
    fi

    tab="$(printf '\t')"
    name="$(${gio} trash --list 2>/dev/null | while IFS="$tab" read -r t_name t_path; do
      if [ "$t_path" = "$target" ]; then
        printf '%s' "$t_name"
        break
      fi
    done)"

    if [ -n "$name" ]; then
      ${gio} trash --restore "trash:///$name" 2>/dev/null
    else
      for info in "${config.xdg.dataHome}/Trash/info"/*.trashinfo; do
        if [ ! -f "$info" ]; then
          continue
        fi

        if grep -q "^Path=$target$" "$info" 2>/dev/null; then
          base="''${info##*/}"
          base="''${base%.trashinfo}"
          if mv "${config.xdg.dataHome}/Trash/files/$base" "$target" 2>/dev/null; then
            rm -f "$info"
          fi
          break
        fi
      done
    fi
  '';
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

      -- NOTE: pywal
      local function reload_theme()
        pcall(dofile, "${wallustColors}")
      end
      swayimg.viewer.on_signal("USR1", reload_theme)
      swayimg.gallery.on_signal("USR1", reload_theme)
      swayimg.slideshow.on_signal("USR1", reload_theme)
      reload_theme()

      -- NOTE: cwall
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

      -- NOTE: cp img
      local function copy_image(img)
        if img then
          os.execute(string.format("${wl-copy} < %q &", img.path))
        end
      end
      swayimg.viewer.on_key("c", function()
        copy_image(swayimg.viewer.get_image())
      end)
      swayimg.gallery.on_key("c", function()
        copy_image(swayimg.gallery.get_image())
      end)
      swayimg.slideshow.on_key("c", function()
        copy_image(swayimg.slideshow.get_image())
      end)

      -- NOTE: cp path
      local function copy_path(img)
        if img then
          os.execute(string.format("printf '%%s' %q | ${wl-copy} &", img.path))
        end
      end
      swayimg.viewer.on_key("p", function()
        copy_path(swayimg.viewer.get_image())
      end)
      swayimg.gallery.on_key("p", function()
        copy_path(swayimg.gallery.get_image())
      end)
      swayimg.slideshow.on_key("p", function()
        copy_path(swayimg.slideshow.get_image())
      end)

      -- NOTE: trash
      local trash_history = {}

      local function trash_image(img)
        if img then
          table.insert(trash_history, img.path)
          os.execute(string.format("${gio} trash %q &", img.path))
          swayimg.imagelist.remove(img.path)
        end
      end

      local function undo_trash()
        if #trash_history > 0 then
          local path = table.remove(trash_history)
          os.execute(string.format("${restoreTrash} %q", path))
          if swayimg.mode == "viewer" then
            swayimg.viewer.open_path(path)
          elseif swayimg.mode == "gallery" then
            swayimg.gallery.reload()
            swayimg.gallery.select_path(path)
          elseif swayimg.mode == "slideshow" then
            swayimg.slideshow.open_path(path)
          end
        end
      end

      swayimg.viewer.on_key("d", function()
        trash_image(swayimg.viewer.get_image())
      end)
      swayimg.viewer.on_key("u", undo_trash)

      swayimg.gallery.on_key("d", function()
        trash_image(swayimg.gallery.get_image())
      end)
      swayimg.gallery.on_key("u", undo_trash)

      swayimg.slideshow.on_key("d", function()
        trash_image(swayimg.slideshow.get_image())
      end)
      swayimg.slideshow.on_key("u", undo_trash)

      -- NOTE: vim
      swayimg.viewer.on_key({ "Down", "KP_Down", "Right", "KP_Right", "l", "j" }, function()
        swayimg.viewer.open("next")
      end)
      swayimg.viewer.on_key({ "Up", "KP_Up", "Left", "KP_Left", "h", "k" }, function()
        swayimg.viewer.open("prev")
      end)
      swayimg.viewer.on_key("g", function()
        swayimg.viewer.open("first")
      end)
      swayimg.viewer.on_key({ "Shift+g", "Shift-g" }, function()
        swayimg.viewer.open("last")
      end)

      swayimg.gallery.on_key("h", function()
        swayimg.gallery.select("left")
      end)
      swayimg.gallery.on_key("l", function()
        swayimg.gallery.select("right")
      end)
      swayimg.gallery.on_key("k", function()
        swayimg.gallery.select("up")
      end)
      swayimg.gallery.on_key("j", function()
        swayimg.gallery.select("down")
      end)
      swayimg.gallery.on_key("g", function()
        swayimg.gallery.select("first")
      end)
      swayimg.gallery.on_key({ "Shift+g", "Shift-g" }, function()
        swayimg.gallery.select("last")
      end)

      swayimg.slideshow.on_key({ "Right", "KP_Right", "l", "j", "Down", "KP_Down" }, function()
        swayimg.slideshow.open("next")
      end)
      swayimg.slideshow.on_key({ "Left", "KP_Left", "h", "k", "Up", "KP_Up" }, function()
        swayimg.slideshow.open("prev")
      end)
      swayimg.slideshow.on_key("g", function()
        swayimg.slideshow.open("first")
      end)
      swayimg.slideshow.on_key({ "Shift+g", "Shift-g" }, function()
        swayimg.slideshow.open("last")
      end)
    '';
  };

  programs.wallust.settings = {
    hooks.swayimg = "${lib.getExe' pkgs.procps "pkill"} -USR1 -x swayimg || true";
    templates.swayimg = {
      template = pkgs.writeText "swayimg.lua" ''
        swayimg.text.color = 0xff{{foreground | strip}}
        swayimg.text.shadow = 0x80{{background | strip}}
        swayimg.viewer.set_window_background(0xff{{background | strip}})
        swayimg.slideshow.set_window_background(0xff{{background | strip}})
        swayimg.gallery.window_color = 0xff{{background | strip}}
        swayimg.gallery.border_color = 0xff{{foreground | strip}}
        swayimg.gallery.selected_color = 0xff{{background | lighten(0.15) | strip}}
        swayimg.gallery.unselected_color = 0xff{{background | lighten(0.05) | strip}}
      '';
      target = wallustColors;
    };
  };
}
