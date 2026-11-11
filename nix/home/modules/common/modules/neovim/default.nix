{ pkgs, inputsSinan, ... }:
let
  nnvim = pkgs.callPackage ./nnvim { };
  nvim-sinan = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.nvim-sinan;
in
{
  home = {
    packages = [
      nnvim
      nvim-sinan
      pkgs.vim
    ];

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };
  };
}
