{
  config,
  pkgs,
  inputs,
  ...
}:
let
  name = config.global.userdata.nameFq;
  email = config.global.userdata.email;
  git = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.git;
in
{
  programs.git = {
    enable = true;
    package = git;
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
