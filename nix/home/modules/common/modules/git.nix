{ config, ... }:
let
  name = config.global.userdata.nameFq;
  email = config.global.userdata.email;
in
{
  programs.git = {
    enable = true;
    settings = {
      gpg.format = "ssh";
      user = {
        inherit name;
        inherit email;
        signingkey = "~/.ssh/id_ed25519.pub";
      };
      commit.gpgsign = true;
      tag.gpgsign = true;
      color.ui = "auto";
      init.defaultBranch = "master";
    };
  };
}
