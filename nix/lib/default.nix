{
  # NOTE: this function links /share, doc, etc... from raw pkgs, so
  # bash-completion, Desktop entries, etc... can be reused
  nixpakEnv =
    {
      buildEnv,
      pkg_raw,
      pkg_nixpak,
    }:
    buildEnv {
      inherit (pkg_raw)
        pname
        version
        meta
        ;
      paths = [
        (buildEnv {
          name = "${pkg_raw.pname}-share";
          paths = [
            pkg_raw
          ];
          pathsToLink = [
            "/share"
          ];
          extraOutputsToInstall = [
            "man"
            "doc"
          ];
        })
        pkg_nixpak
      ];
      pathsToLink = [
        "/share"
        "/bin"
      ];
      extraOutputsToInstall = [
        "man"
        "doc"
      ];
    };
}
