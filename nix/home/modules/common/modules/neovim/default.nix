{ pkgs, inputsSinan, ... }:
let
  nnvim = pkgs.callPackage ./nnvim { };
  svim = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.svim;
in
{
  home = {
    packages = [
      nnvim
      svim
      pkgs.vim
    ];

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };
  };
}
