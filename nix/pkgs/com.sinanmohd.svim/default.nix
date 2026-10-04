{ neovim, pkgs }:
neovim.override {
  extraBins = with pkgs; [
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
    nix
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
  configPath = "${./config}/init.lua";
}
