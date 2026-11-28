{
  config,
  pkgs,
  lib,
  inputsSinan,
  ...
}:
let
  mod = "mod4";
  left = "h";
  right = "l";
  down = "j";
  up = "k";

  wayland-scripts = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.wayland-scripts;
  voxtype = lib.getExe config.services.voxtype.package;
  speak = "${wayland-scripts}/bin/speak";

  font =
    config.global.font.sans.name
    + lib.optionalString (
      config.global.font.sans.sizePx != null
    ) " ${lib.toString config.global.font.sans.sizePx}px";

  # NOTE: browsers resize the picture in picture window whenever the video
  # changes, and sway grows a floating window from its top left corner, so it
  # drifts off the top right one. poll while such a window is open and put it
  # back
  pip_margin = 75;
  pip_anchor = pkgs.writeShellApplication {
    name = "sway-pip-anchor";

    runtimeInputs = with pkgs; [
      coreutils
      jq
      sway
    ];

    text = ''
      # NOTE: prints one line per picture in picture window, like "267 288x164
      # 1227 109": the window id, its current size, and the x and y to move it
      # to so that it sits in the top right corner. Exits non zero when no such
      # window is open, which ends the loop below
      windows() {
        swaymsg -t get_tree | jq -er --argjson margin ${toString pip_margin} '
          .. | objects | select(.type == "workspace") | .rect as $ws
            | .floating_nodes[]
            | select(.fullscreen_mode == 0)
            | select(.name // "" | test("^Picture[- ]in[- ][Pp]icture$"))
            | [
                .id,
                "\(.rect.width)x\(.rect.height)",
                $ws.x + $ws.width - .rect.width - $margin,
                $ws.y + $margin
              ]
            | join(" ")
        '
      }

      # NOTE: only move a window when its not manually dragged away
      seen=
      while current="$(windows)"; do
        printf '%s\n' "$current" | while read -r id size x y; do
          case "$seen" in
          *"$id $size $x $y"*) ;;
          *)
            swaymsg "[con_id=$id] move absolute position $x $y" > /dev/null || :
            ;;
          esac
        done

        seen="$current"
        sleep 0.5
      done
    '';
  };

  picture_in_picture =
    "floating enable, sticky enable, resize set 25 ppt 23 ppt, "
    + "move position 75 ppt 0 ppt, "
    + "move left ${toString pip_margin} px, move down ${toString pip_margin} px, "
    + "exec ${lib.getExe pip_anchor}";

  termux_sway_yazi = pkgs.writeShellApplication {
    name = "termux_sway_yazi";

    runtimeInputs = with pkgs; [
      tmux
      coreutils
      jq
      sway
      inotify-tools
    ];

    text = ''
      session_name="root"
      tmux_sock_path="$XDG_RUNTIME_DIR/tmux-$UID/default"

      is_alacritty_running() {
        while read -r window_name; do
          if [ "$window_name" == "Alacritty" ]; then
              return 0
          fi
          echo "$window_name"
        done < <(swaymsg -t get_tree | jq -r '.. | (.nodes? // empty)[] | select(.pid) | {name} + .rect | "\(.name)"')

        return 1
      }

      is_tmux_running() {
        ss -lx | grep -q "$tmux_sock_path"
      }

      tmux_wait() {
        while inotifywait -re create "$XDG_RUNTIME_DIR"; do
          if is_tmux_running; then
            break
          fi
        done
      }

      if ! is_alacritty_running; then
        setsid alacritty &
      fi
      if ! is_tmux_running; then
        tmux_wait
      else
        tmux new-window -t "$session_name"
      fi

      tmux send-keys -t "$session_name" '${config.programs.yazi.shellWrapperName} && echo -en "\033[2A\033[0J"' Enter
    '';
  };
in
{
  imports = [
    ./theme.nix
    ./swayidle.nix
    ./swaylock.nix
  ];

  programs.bash.profileExtra = ''
    case "$(tty)" in
    */tty1) exec sway --unsupported-gpu ;;
    esac
  '';

  home = {
    packages = [
      pkgs.wl-clipboard
      pkgs.swayidle
      pkgs.brightnessctl
      pkgs.playerctl
      wayland-scripts
      termux_sway_yazi
    ];

    sessionVariables = {
      SUDO_ASKPASS = "${wayland-scripts}/bin/daskpass";
      XDG_CURRENT_DESKTOP = "sway";
      GRIM_DEFAULT_DIR = config.xdg.userDirs.pictures + "/ss";
    };
  };

  programs.wallust.settings = {
    hooks.sway = "swaymsg  reload";
    templates.sway = {
      template = pkgs.writeText "sway.conf" ''
        client.focused          {{foreground}}     {{background}}     {{foreground}}  {{foreground}}       {{foreground}}
        client.placeholder      {{foreground}}     {{background}}     {{foreground}}  {{foreground}}       {{foreground}}

        client.focused_inactive {{foreground}}     {{background}}     {{foreground | darken(0.4)}}  {{foreground}}       {{foreground | darken(0.4)}}
        client.unfocused        {{foreground}}     {{background}}     {{foreground | darken(0.4)}}  {{foreground}}       {{foreground | darken(0.4)}}

        client.urgent           {{foreground}}     {{background}}     {{foreground}}  {{foreground}}       {{foreground}}

        client.background                          {{background}}
      '';
      target = "~/.local/share/wallust/sway.conf";
    };
  };

  wayland.windowManager.sway = {
    enable = true;
    checkConfig = true;
    config = null;

    settings = {
      include = "~/.local/share/wallust/sway.conf";
      font = "pango:${font}";
      for_window = {
        "[app_id=floater]" = "floating enable";
        "[app_id=org.kde.kdeconnect.app]" = "floating enable";
        "[app_id=xdg-desktop-portal-gtk]" = "floating enable";
        "[app_id=firefox title=^Library$]" = "floating enable";
        "[app_id=firefox title=^Picture-in-Picture$]" = picture_in_picture;
        # NOTE: float qbit's add torrent dialog is titled after the torrent
        "[app_id=org.qbittorrent.qBittorrent title=\"^(?!.*qBittorrent v[0-9])\"]" = "floating enable";
        # NOTE: chromium's picture in picture window has no app_id
        "[app_id=^$ title=\"^Picture in picture$\"]" = picture_in_picture;
        # NOTE: client side decorated windows (gtk file picker) gets border
        "[all]" = "border pixel 2";
        # NOTE: the presenter pointer is a transparent fullscreen window, and
        # sway draws nothing but black behind a fullscreen one unlike KDE.
        "[app_id=org.kde.kdeconnect.daemon title=\"^KDE Connect Daemon$\"]" =
          "fullscreen disable, floating enable, border none, resize set 100 ppt 100 ppt, move position center";
      };
      assign = {
        "[app_id=Alacritty]" = 1;
        "[app_id=firefox]" = 2;

        "[app_id=org.qbittorrent.qBittorrent title=\"qBittorrent v[0-9]\"]" = 6;
        "[app_id=chromium-browser]" = 7;
        "[app_id=slack]" = 8;
        "[app_id=element]" = 9;
      };

      bindgesture = {
        "swipe:left" = "workspace next";
        "swipe:right" = "workspace prev";
        "swipe:down" = "exec ${lib.getExe config.programs.swaylock.package}";
        "swipe:up" = "exec ${wayland-scripts}/bin/cwall";
      };
      input = {
        "type:touchpad" = {
          dwt = "enabled";
          tap = "enabled";
          natural_scroll = "enabled";
        };
        "type:keyboard" = {
          repeat_rate = 100;
          repeat_delay = 250;
        };
      };

      bindsym =
        let
          alacritty = lib.getExe pkgs.alacritty;
        in
        {
          # basics
          "${mod}+q" = "kill";
          "${mod}+shift+c" = "reload";
          "${mod}+shift+e" = ''
            	  exec swaynag -t warning -m 'Do you really want to exit sway?' \
            	      -B 'Yes, exit sway' 'swaymsg exit'
            	'';

          # workspaces
          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";
          "${mod}+6" = "workspace number 6";
          "${mod}+7" = "workspace number 7";
          "${mod}+8" = "workspace number 8";
          "${mod}+9" = "workspace number 9";
          "${mod}+tab" = "workspace back_and_forth";
          "${mod}+shift+1" = "move container to workspace number 1";
          "${mod}+shift+2" = "move container to workspace number 2";
          "${mod}+shift+3" = "move container to workspace number 3";
          "${mod}+shift+4" = "move container to workspace number 4";
          "${mod}+shift+5" = "move container to workspace number 5";
          "${mod}+shift+6" = "move container to workspace number 6";
          "${mod}+shift+7" = "move container to workspace number 7";
          "${mod}+shift+8" = "move container to workspace number 8";
          "${mod}+shift+9" = "move container to workspace number 9";
          "${mod}+c" = "splitv";
          "${mod}+v" = "splith";

          # layout
          "${mod}+${left}" = "focus left";
          "${mod}+${down}" = "focus down";
          "${mod}+${up}" = "focus up";
          "${mod}+${right}" = "focus right";
          "${mod}+shift+${left}" = "move left";
          "${mod}+shift+${right}" = "move right";
          "${mod}+shift+${down}" = "move down";
          "${mod}+shift+${up}" = "move up";
          "${mod}+f" = "fullscreen";
          "${mod}+s" = "layout stacking";
          "${mod}+t" = "layout tabbed";
          "${mod}+e" = "layout toggle split";
          "${mod}+shift+space" = "floating toggle";
          "${mod}+r" = "mode resize";

          # scratchpad
          "${mod}+shift+minus" = "move scratchpad";
          "${mod}+minus" = "scratchpad show";

          # exec
          "print" = "exec ${wayland-scripts}/bin/freezshot";
          "${mod}+return" = "exec ${lib.getExe config.programs.alacritty.package}";
          "${mod}+a" = "exec ${wayland-scripts}/bin/damb";
          "${mod}+d" = "exec ${wayland-scripts}/bin/dbook";
          "${mod}+o" = "exec ${lib.getExe config.programs.fuzzel.package}";
          "${mod}+w" = "exec ${lib.getExe config.programs.firefox.finalPackage}";
          "${mod}+backslash" = "exec ${lib.getExe termux_sway_yazi}";

          # voxtype
          "--no-repeat ${mod}+shift+x" = "exec ${voxtype} record start";
          "--release ${mod}+shift+x" = "exec ${voxtype} record stop";

          # speak
          "${mod}+shift+z" =
            "exec ${lib.getExe' pkgs.wl-clipboard "wl-paste"} --primary --no-newline | ${speak}";

          # menu
          "${mod}+z" = "exec ${alacritty} --class floater -e ${lib.getExe pkgs.impala}";
          "${mod}+x" = "exec ${alacritty} --class floater -e ${lib.getExe pkgs.bluetui}";
          "${mod}+bracketleft" = "exec ${alacritty} --class floater -e ${lib.getExe pkgs.wiremix}";
          "${mod}+semicolon" = "exec ${alacritty} --class floater -e ${lib.getExe pkgs.btop}";
          "${mod}+comma" = "exec ${alacritty} --class floater -e sudo /run/current-system/sw/bin/powertop";
          "${mod}+period" = "exec ${alacritty} --class floater -e ${lib.getExe' pkgs.calcurse "calcurse"}";
          "${mod}+slash" =
            "exec ${alacritty} --class floater -e ${lib.getExe pkgs.tmux} new-session -A -s float";

          # brightness
          XF86MonBrightnessDown = "exec ${lib.getExe pkgs.brightnessctl} set 1%-";
          XF86MonBrightnessUp = "exec ${lib.getExe pkgs.brightnessctl} set 1%+";

          # music
          XF86AudioPlay = "exec ${lib.getExe pkgs.playerctl} play-pause";
          XF86AudioStop = "exec ${lib.getExe pkgs.playerctl} stop";
          XF86AudioPrev = "exec ${lib.getExe pkgs.playerctl} previous";
          XF86AudioNext = "exec ${lib.getExe pkgs.playerctl} next";

          # volume
          XF86AudioLowerVolume = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          XF86AudioRaiseVolume = "exec ${pkgs.wireplumber}/bin/wpctl set-volume --limit 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
          XF86AudioMute = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          XF86AudioMicMute = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        };

      mode.resize.bindsym = {
        ${left} = "resize shrink width 10px";
        ${right} = "resize grow width 10px";
        ${down} = "resize grow height 10px";
        ${up} = "resize shrink height 10px";
        return = "mode default";
      };

      # voxtype
      mode.voxtype_is_recording.bindsym."${mod}+shift+a" = "exec ${voxtype} record cancel; mode default";
      # NOTE: voxtype switches here while typing so held modifiers don't turn
      # text into shortcuts.
      mode.voxtype_is_typing.bindsym =
        lib.genAttrs [
          "Super_L"
          "Super_R"
          "Control_L"
          "Control_R"
          "Alt_L"
          "Alt_R"
          "Shift_L"
          "Shift_R"
        ] (_: "nop")
        // {
          # NOTE: escape hatch if voxtype dies mid-output
          "${mod}+shift+a" = "mode default";
        };

      exec = [ (lib.getExe config.services.mako.package) ];
      gaps.inner = 10;
      default_border.pixel = 2;
      hide_edge_borders = "--i3 none";
      workspace_layout = "tabbed";
      xwayland = "disable";
      floating_modifier = "${mod} normal";
    };
  };
}
