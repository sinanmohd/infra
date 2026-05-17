{ pkgs, ... }:
{
  environment = {
    systemPackages = with pkgs; [ neovim ];

    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    shellAliases = {
      grep = "grep --color=auto";
      ls = "ls --color=auto --group-directories-first";
    };
  };
}
