{ pkgs, ... }:
{
  home.packages = [ pkgs.p7zip ];

  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    package = pkgs.yazi.override {
      yazi-unwrapped = pkgs.yazi-unwrapped.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          ./0001-emulator-never-probe-through-tmux-passthrough.patch
        ];
      });
    };

    settings.mgr = {
      ratio = [
        0
        1
        1
      ];
      linemode = "size";
    };
  };
}
