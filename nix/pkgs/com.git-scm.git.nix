{
  lib,
  pkgs,
  nixpak,
  git,
  buildEnv,
  libSinan,
}:
let
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  nixpak-git = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkgs.git;

      bubblewrap = {
        # NOTE: git diff
        newSession = true;
        # NOTE: ssh commit signing writes tmp files via $TMPDIR
        tmpfs = [ "/tmp" ];
        clearEnv = true;
        env = {
          HOME = sloth.env "HOME";
          TERM = sloth.env "TERM";
          EDITOR = sloth.env "EDITOR";
          PATH = sloth.env "PATH";
        };
        bind = {
          ro = [
            # NOTE: nix hook bins
            (sloth.env "_NIX_USER_BINS")
            "/run/current-system/sw/bin"
            # NOTE: git EDITOR
            (sloth.concat' sloth.xdgConfigHome "/nvim")
            # NOTE: ssh commit signing & push
            "/etc/passwd"
            (sloth.concat' sloth.homeDir "/.ssh/id_ed25519")
            (sloth.concat' sloth.homeDir "/.ssh/id_ed25519.pub")
          ];
          rw = [
            (sloth.concat' sloth.xdgConfigHome "/git")
            # NOTE: repo root
            (sloth.env "RW_ROOT")
            # NOTE: git EDITOR
            (sloth.concat' sloth.xdgStateHome "/nvim")
            (sloth.concat' sloth.xdgDataHome "/nvim")
            (sloth.concat' sloth.xdgCacheHome "/nvim")
            (sloth.concat' sloth.homeDir "/.ssh/known_hosts")
          ];
        };
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit buildEnv;
  pkg_raw = pkgs.git;
  pkg_nixpak = pkgs.writeShellScriptBin "git" ''
    # NOTE: allows access to user bin
    export _NIX_USER_BINS="/etc/profiles/per-user/$USER/bin"

    if [ -z "$RW_ROOT" ]; then
      if rw_root="$(${lib.getExe git} rev-parse --show-toplevel 2>/dev/null)"; then
        export RW_ROOT="$rw_root"
      else
        export RW_ROOT="$PWD"
      fi
    fi

    exec ${lib.getExe nixpak-git.config.script} "$@"
  '';
}
