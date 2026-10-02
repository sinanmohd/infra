{ pkgs, inputs, ... }:
let
  nnvim = pkgs.callPackage ./nnvim { };
  neovim = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.neovim;
in
{
  home = {
    packages = with pkgs; [
      neovim
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

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  xdg.configFile.nvim.source = ./config;
}
