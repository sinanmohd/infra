{
  config,
  pkgs,
  lib,
  inputsSinan,
  ...
}:
let
  username = config.global.userdata.name;
  wrap = inputsSinan.wrap.packages.${pkgs.stdenv.hostPlatform.system}.wrap;
  # NOTE: nixpak git can't see ~/.cache/nix/gitv3
  nix = pkgs.writeShellScriptBin "nix" ''
    export PATH="${lib.makeBinPath [ pkgs.git ]}:$PATH"
    exec ${lib.getExe pkgs.nix} "$@"
  '';
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
      bash-prompt-prefix = "";
    };
  };

  home = {
    inherit username;
    stateVersion = "26.05";
    homeDirectory = "/home/${config.home.username}";

    packages = with pkgs; [
      nix
      unzip
      curl
      file
      ps_mem
      jq

      dig
      tcpdump
      mtr
      geoipWithDatabase
      wrap
    ];
  };
}
