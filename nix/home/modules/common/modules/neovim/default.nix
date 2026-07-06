{ pkgs, ... }:
let
  nnvim = pkgs.callPackage ./nnvim { };
in
{
  home.packages = with pkgs; [
    nnvim
    # telescope
    ripgrep
    fd
    # lazy
    gcc
    gnumake
    # toggleterm
    tmux
    # lsp
    ccls
    pyright
    rust-analyzer
    yaml-language-server
    terraform-ls
    bash-language-server
    nil
    tailwindcss-language-server
    helm-ls
    gopls
    go
    vue-language-server
    luajitPackages.lua-lsp
    markdownlint-cli
  ];

  xdg.configFile.nvim.source = ./config;
}
