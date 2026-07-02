{ pkgs, lib, ... }:
{
  programs = {
    kubecolor = {
      enable = true;
      enableAlias = true;
    };
    k9s = {
      enable = true;
      plugins = {
        debug-container = lib.fromTOML ((lib.readFile ./plugins/debug-container.toml));
        pvc-resize = lib.fromTOML ((lib.readFile ./plugins/pvc-resize.toml));
      };
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
    velero
    (wrapHelm kubernetes-helm {
      plugins = with pkgs.kubernetes-helmPlugins; [
        helm-secrets
        helm-diff
      ];
    })

    kubectl
  ];
}
