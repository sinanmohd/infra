{ pkgs, ... }:
{
  home.packages = with pkgs; [
    element-desktop
  ];

  programs.wallust.settings = {
    hooks.element = ''
      pkill -9 electron
      element-desktop
    '';
    templates.element = {
      template = pkgs.writeText "colors.json" ''
        {
          "setting_defaults": {
            "custom_themes": [
              {
                "name": "wallust",
                "is_dark": true,
                "colors": {
                  "accent-color": "{{foreground}}",
                  "accent": "{{foreground}}",
                  "primary-color": "{{foreground}}",
                  "warning-color": "{{foreground}}",
                  "alert": "{{foreground}}",
                  "sidebar-color": "{{foreground | darken(0.4)}}",
                  "roomlist-background-color": "{{background}}",
                  "roomlist-text-color": "{{foreground}}",
                  "roomlist-text-secondary-color": "{{foreground | darken(0.4)}}",
                  "roomlist-highlights-color": "{{background | lighten(0.2)}}",
                  "roomlist-separator-color": "{{foreground | darken(0.4)}}",
                  "timeline-background-color": "{{background}}",
                  "timeline-text-color": "{{foreground}}",
                  "secondary-content": "{{foreground}}",
                  "tertiary-content": "{{foreground}}",
                  "timeline-text-secondary-color": "{{foreground | darken(0.4)}}",
                  "timeline-highlights-color": "{{background | lighten(0.2)}}",
                  "reaction-row-button-selected-bg-color": "{{background | lighten(0.2)}}",
                  "menu-selected-color": "{{background | lighten(0.2)}}",
                  "focus-bg-color": "{{background | lighten(0.2)}}",
                  "room-highlight-color": "{{background | lighten(0.2)}}",
                  "other-user-pill-bg-color": "{{background | lighten(0.2)}}",
                  "togglesw-off-color": "{{foreground | darken(0.4)}}"
                },
                "compound": {
                  "--cpd-color-theme-bg": "{{color10}}",
                  "--cpd-color-bg-canvas-default": "{{background}}",
                  "--cpd-color-bg-subtle-secondary": "{{background}}",
                  "--cpd-color-bg-subtle-primary": "{{background | lighten(0.2)}}",
                  "--cpd-color-bg-action-primary-rest": "{{foreground}}",
                  "--cpd-color-bg-action-secondary-rest": "{{background}}",
                  "--cpd-color-bg-critical-subtle": "{{background | lighten(0.2)}}",
                  "--cpd-color-bg-accent-rest": "{{foreground}}",
                  "--cpd-color-text-primary": "{{foreground}}",
                  "--cpd-color-text-secondary": "{{foreground | darken(0.4)}}",
                  "--cpd-color-text-action-accent": "{{foreground | darken(0.4)}}",
                  "--cpd-color-text-success-primary": "{{foreground}}",
                  "--cpd-color-icon-primary": "{{foreground}}",
                  "--cpd-color-icon-secondary": "{{foreground}}",
                  "--cpd-color-icon-tertiary": "{{foreground}}",
                  "--cpd-color-icon-accent-tertiary": "{{foreground}}",
                  "--cpd-color-border-interactive-primary": "{{foreground}}",
                  "--cpd-color-border-interactive-secondary": "{{foreground}}",
                  "--cpd-color-border-success-subtle": "{{foreground}}"
                }
              }
            ]
          }
        }
      '';
      target = "~/.config/Element/config.json";
    };
  };
}
