{ pkgs, inputs, ... }:
let
  nnvim = pkgs.callPackage ./nnvim { };
  svim = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.svim;
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
