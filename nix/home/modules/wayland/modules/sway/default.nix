{
  config,
  pkgs,
  lib,
  ...
}:
let
  mod = "mod4";
  left = "h";
  right = "l";
  down = "j";
  up = "k";

  background = "${config.xdg.dataHome}/wayland/desktop";
  wayland-scripts = pkgs.callPackage ../../pkgs/wayland-scripts { };
  cwall = "${wayland-scripts}/bin/cwall";
  daskpass = "${wayland-scripts}/bin/daskpass";

  bemenu = "${pkgs.bemenu}/bin/bemenu-run --prompt ' '";
  foot = lib.getExe config.programs.foot.package;
  swaylock = lib.getExe config.programs.swaylock.package;

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
      session_name="_root_session_managed_by_home_manager"
      tmux_sock_path="$XDG_RUNTIME_DIR/tmux-$UID/default"

      is_foot_running() {
        while read -r window_name; do
          if [ "$window_name" == "foot" ]; then
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

      if ! is_foot_running; then
        setsid foot &
      fi
      if ! is_tmux_running; then
        tmux_wait
      else
        tmux new-window -t "$session_name"
      fi

      tmux send-keys -t "$session_name" '${config.programs.yazi.shellWrapperName} && echo -en "\033[2A\033[0J"' Enter
    '';
  };
  yazi = lib.getExe termux_sway_yazi;

  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  brightnessctl = lib.getExe pkgs.brightnessctl;
  freezshot = "${wayland-scripts}/bin/freezshot";
  damb = "${wayland-scripts}/bin/damb";
  dbook = "${wayland-scripts}/bin/dbook";
  mako = lib.getExe config.services.mako.package;
  firefox = lib.getExe config.programs.firefox.finalPackage;
in
{
  imports = [
    ./mako.nix
    ./theme.nix
    ./bemenu.nix
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
      pkgs.bemenu
      pkgs.swayidle
      pkgs.brightnessctl
      pkgs.pwvucontrol
      wayland-scripts
      termux_sway_yazi
    ];

    sessionVariables = {
      SUDO_ASKPASS = daskpass;
      XDG_CURRENT_DESKTOP = "sway";
      GRIM_DEFAULT_DIR = config.xdg.userDirs.pictures + "/ss";
    };
  };

  wayland.windowManager.sway = {
    enable = true;
    # checkConfig fails if ${background} doesn't exist
    checkConfig = false;
    config = null;

    settings = {
      assign = {
        "[app_id=foot]" = 1;
        "[app_id=firefox]" = 2;

        "[app_id=Slack]" = 8;
        "[app_id=Element]" = 9;
      };

      bindgesture = {
        "swipe:left" = "workspace next";
        "swipe:right" = "workspace prev";
        "swipe:down" = "exec ${swaylock}";
        "swipe:up" = "exec ${cwall}";
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

      bindsym = {
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
        "print" = "exec ${freezshot}";
        "${mod}+return" = "exec ${foot}";
        "${mod}+a" = "exec ${damb}";
        "${mod}+d" = "exec ${dbook}";
        "${mod}+o" = "exec ${bemenu}";
        "${mod}+w" = "exec ${firefox}";
        "${mod}+backslash" = "exec ${yazi}";

        XF86MonBrightnessDown = "exec ${brightnessctl} set 1%-";
        XF86MonBrightnessUp = "exec ${brightnessctl} set 1%+";
        XF86AudioLowerVolume = "exec ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        XF86AudioRaiseVolume = "exec ${wpctl} set-volume --limit 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
        XF86AudioMute = "exec ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
        XF86AudioMicMute = "exec ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      };

      mode.resize.bindsym = {
        ${left} = "resize shrink width 10px";
        ${right} = "resize grow width 10px";
        ${down} = "resize grow height 10px";
        ${up} = "resize shrink height 10px";
        return = "mode default";
      };

      exec = [ mako ];
      gaps.inner = 10;
      default_border.pixel = 2;
      floating_modifier = "${mod} normal";
      output."*".background = "${background} fill";
      "client.focused" = "#4c7899 #285577 #ffffff #285577";
    };
  };
}
