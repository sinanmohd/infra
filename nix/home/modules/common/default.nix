{
  config,
  pkgs,
  lib,
  ...
}:
let
  username = config.global.userdata.name;
in
{
  imports = [
    ../../../global/modules/common

    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/shell.nix
    ./modules/xdgdirs.nix
    ./modules/mimeapps.nix
    ./modules/xdg_ninja.nix
    ./modules/ssh.nix
    ./modules/dev.nix
    ./modules/neovim
    ./modules/yazi.nix
    ./modules/btop.nix
    ./modules/font.nix
  ];

  programs.home-manager.enable = true;

  nix = {
    package = lib.mkForce pkgs.nix;
    settings = {
      use-xdg-base-directories = true;
      bash-prompt-prefix = "";
    };
  };

  home = {
    inherit username;
    stateVersion = "26.05";
    homeDirectory = "/home/${config.home.username}";

    packages = with pkgs; [
      unzip
      curl
      file
      ps_mem
      jq

      dig
      tcpdump
      mtr
      geoipWithDatabase
    ];
  };
}
