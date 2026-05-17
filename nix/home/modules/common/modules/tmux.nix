{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [ tmux ];

  home.sessionVariables.TMUX_TMPDIR = ''''${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}'';
  programs.bash.initExtra = lib.mkOrder 2000 ''
    if [ -z "$TMUX" ] &&
      { [ -n "$WAYLAND_DISPLAY" ] || [ -n "$SSH_TTY" ]; }; then
        exec tmux new-session -A -s _root_session_managed_by_home_manager > /dev/null 2>&1
    fi
  '';

  xdg.configFile."tmux/tmux.conf".text = ''
    # base
    set-option -g prefix C-a
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
    set -g window-status-current-format '#{window_index}:#(basename #{pane_current_path})(#{pane_current_command})*'
    set -g window-status-format '#{window_index}:#(basename #{pane_current_path})(#{pane_current_command})'

    # nvim.checkhealth: without this |'autoread'| may not work
    set-option -g focus-events on
  '';
}
