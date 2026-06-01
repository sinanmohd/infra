{ pkgs, ... }:
{
  programs.bash.enable = true;

  home = {
    packages = with pkgs; [
      neovim
      eza
      bat
      util-linux # for col
    ];

    shellAliases = {
      l = "eza -l --group-directories-first --icons=auto";
      grep = "grep --color=auto";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";
      cat = "bat --style='changes,snip'";

      gs = "git status";
      gl = "git log";
      gm = "git commit -a -m";
      ga = "git commit -a --amend";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      MANROFFOPT = "-c";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };
  };
}
