{ pkgs, ... }:
{
  home.packages = with pkgs; [
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
    vue-language-server
    luajitPackages.lua-lsp
  ];

  xdg.configFile.nvim.source = ./config;
}
