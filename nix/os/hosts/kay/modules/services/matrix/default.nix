{
  pkgs,
  lib,
  ...
}:
{
  disabledModules = [
    "services/matrix/dendrite.nix"
  ];
  imports = [
    ./dendrite.nix
    ./dendrite-nixpkgs-patch.nix
  ];

  services.dendrite.package = pkgs.dendrite.overrideAttrs (o: rec {
    pname = "zendrite";
    version = "3.1.0";

    src = pkgs.fetchgit {
      url = "https://codefloe.com/pat-s/zendrite.git";
      rev = "refs/tags/v${version}";
      hash = "sha256-EkW5eiVN6TGRbVb7w/+AEihZm9tQnToPQqsKYo4wVNE=";
    };

    subPackages = [
      # The server
      "cmd/zendrite"
      # admin tools
      "cmd/create-account"
      "cmd/generate-config"
      "cmd/generate-keys"
      "cmd/resolve-state"
      ## curl, but for federation requests, only useful for developers
      # "cmd/furl"
      ## an internal tool for upgrading ci tests, only relevant for developers
      # "cmd/dendrite-upgrade-tests"
    ];

    vendorHash = "sha256-KRea2C9/uUD5Yh/KWtyFdlmbjyk+l8VTraTsDYJlxC4=";

    meta = {
      homepage = " https://zendrite.pat-s.me";
      mainProgram = "zendrite";
      description = "An opinionated fork of element-hq/dendrite https://zendrite.pat-s.me";
      changelog = "https://codefloe.com/pat-s/zendrite/releases/tag/v${version}";
      license = lib.licenses.agpl3Plus;
      platforms = lib.platforms.unix;
    };
  });
}
