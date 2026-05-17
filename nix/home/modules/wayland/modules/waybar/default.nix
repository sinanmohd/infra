{ pkgs, ... }:
{
  systemd.user.services.waybar.Service.Environment = "PATH=${
    pkgs.wttrbar.overrideAttrs {
      src = pkgs.fetchFromGitHub {
        owner = "sinanmohd";
        repo = "wttrbar";
        rev = "feat/align-text";
        hash = "sha256-QwLaVfLhI1mH22z+RDvpxH1n1GtbrEKG3eYPG1L/aU0=";
      };
    }
  }/bin";

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = builtins.readFile ./style.css;
    settings.master = builtins.fromJSON (builtins.readFile ./config.json);
  };
}
