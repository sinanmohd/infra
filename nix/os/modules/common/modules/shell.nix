{ pkgs, ... }:
{
  environment = {
    systemPackages = with pkgs; [ neovim ];

    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  programs.bash.promptInit = ''
    if [ "$UID" -ne 0 ]; then
        PROMPT_COLOR="1;32m"
    else
        PROMPT_COLOR="1;31m"
    fi

    PS1="\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\\$\[\033[0m\] "
  '';
}
