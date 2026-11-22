{ pkgs, lib, ... }:
let
  # TODO: drop once merged to nixpkgs, fix for sixel err
  tmux = pkgs.tmux.overrideAttrs {
    version = "next-3.9";
    src = pkgs.fetchFromGitHub {
      owner = "tmux";
      repo = "tmux";
      rev = "c8427d6be82364823326b49d90d73952e4f63881"; # NOTE: master at time of fix
      hash = "sha256-JVXauUm+Olwpbj9DMh/R2YseNr4EfdYbsXylb3lxz4o=";
    };
  };

  # NOTE: tmux only applies update-environment when a client
  # attaches, so a mosh/ssh client attaching to the shared session unsets
  # WAYLAND_DISPLAY and the long lived desktop client never puts it back.
  # Redo the same thing whenever a client becomes the active one, reading
  # the variables from that client's own environment
  sync-env = pkgs.writeScript "tmux-sync-env" ''
    #!/bin/sh
    PATH=${
      lib.makeBinPath [
        tmux
        pkgs.coreutils
        pkgs.gnugrep
      ]
    }

    pid="$1"
    session="$2"
    environ="/proc/$pid/environ"
    if ! [ -r "$environ" ]; then
      exit 0
    fi

    tmux show-options -gv update-environment | while read -r var; do
      line=$(tr '\0' '\n' < "$environ" | grep -m 1 "^$var=")
      if [ -n "$line" ]; then
        tmux set-environment -t "$session" "$var" "''${line#*=}"
      else
        tmux set-environment -t "$session" -r "$var"
      fi
    done
  '';
in
{
  home.packages = [ tmux ];

  home.sessionVariables.TMUX_TMPDIR = ''''${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}'';
  programs.bash.initExtra = lib.mkOrder 2000 ''
    if [ -z "$TMUX" ] &&
      { [ -n "$WAYLAND_DISPLAY" ] || [ -n "$SSH_TTY" ]; }; then
        exec tmux new-session -A -s root > /dev/null 2>&1
    fi

    if [ -n "$TMUX" ]; then
      __tmux_sync_env() {
        eval "$(tmux show-environment -s 2> /dev/null)"
      }
      PS0="''${PS0}\''${ __tmux_sync_env; }"
    fi
  '';

  xdg.configFile."tmux/tmux.conf".text = ''
    # base
    set-option -g prefix C-a
    set -g mouse off
    unbind-key C-b
    bind-key C-a send-prefix
    set -g base-index 1
    setw -g pane-base-index 1
    set -g history-limit 10000

    # kill the current pane
    bind -n C-x kill-pane

    # vim
    set -g mode-keys vi
    bind -T copy-mode-vi v send -X begin-selection
    bind -T copy-mode-vi y send -X copy-selection
    bind -r C-w last-window

    bind -r h select-pane -L
    bind -r j select-pane -D
    bind -r k select-pane -U
    bind -r l select-pane -R

    bind -r H resize-pane -L 5
    bind -r J resize-pane -D 5
    bind -r K resize-pane -U 5
    bind -r L resize-pane -R 5

    bind -r C-h select-window -t :-
    bind -r C-l select-window -t :+

    # not eye candy
    set -g status-style "bg=default fg=7"
    set -g status-left ""
    set -g status-right ""
    set -g status-justify right
    set -g window-status-current-format '#{window_index}:#(basename #{pane_current_path})(#{pane_current_command})'
    set -g window-status-format '#{window_index}:#(basename #{pane_current_path})(#{pane_current_command})'

    # nvim.checkhealth: without this |'autoread'| may not work
    set-option -g focus-events on

    # NOTE: room for one big sixel image
    set -s input-buffer-size 104857600

    # NOTE: sync update-environment from the last used client
    set-hook -g client-active 'run-shell "${sync-env} #{client_pid} \"#{session_name}\""'
  '';
}
