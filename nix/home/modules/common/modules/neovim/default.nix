{ pkgs, ... }:
let
  nnvim = pkgs.callPackage ./nnvim { };
in
{
  home.packages = with pkgs; [
    nnvim
    inotify-tools
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
    rustc
    cargo
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
    mdx-language-server
    lua-language-server
    typescript
  ];

  xdg.configFile.nvim.source = ./config;
}
