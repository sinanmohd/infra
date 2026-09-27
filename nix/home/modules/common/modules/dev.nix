{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sops

    linux-manual
    man-pages
    man-pages-posix

    nil
    bash-language-server
  ];
}
