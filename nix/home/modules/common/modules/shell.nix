{ pkgs, ... }:
{
  programs.bash.enable = true;

  home = {
    packages = with pkgs; [ neovim ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
