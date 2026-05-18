{ pkgs, lib, ... }:
{
  programs = {
    kubecolor = {
      enable = true;
      enableAlias = true;
    };
    k9s = {
      enable = true;
      plugins.debug-container = lib.fromTOML ((lib.readFile ./debug-container.toml));
      skins = {
        transparency = {
          k9s = {
            body.bgColor = "default";
            frame = {
              crumbs.bgColor = "default";
              title.bgColor = "default";

            };
            views = {
              table = {
                bgColor = "default";
                header.bgColor = "default";
              };
              logs.bgColor = "default";
            };
          };
        };
      };

      settings.ui.splashless = true;
    };
  };

  home.packages = with pkgs; [
    kubernetes-helm
    kubectl
  ];
}
