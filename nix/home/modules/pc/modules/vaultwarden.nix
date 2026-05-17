{ config, pkgs, ... }:
let
  email = config.global.userdata.email;
  domain = "https://vaultwarden.${config.global.userdata.domain}";
in
{
  programs.rbw = {
    enable = true;
    settings = {
      inherit email;
      base_url = domain;
      pinentry = pkgs.pinentry-bemenu;
    };
  };
}
