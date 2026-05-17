{
  config,
  ...
}:
let
  user = config.global.userdata.name;
in
{
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 16d";
    };

    settings = {
      auto-optimise-store = true;
      use-xdg-base-directories = true;
      trusted-users = [ user ];

      experimental-features = [
        "flakes"
        "nix-command"
      ];

      substituters = [
        # "https://nixbin.sinanmohd.com"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        # "nixbin.sinanmohd.com:dXV3KDPVrm+cGJ2M1ZmTeQJqFGaEapqiVoWHgYDh03k="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
