{
  lib,
  pkgs,
  nixpak,
  git,
}:
let
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  nixpak-git = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkgs.git;

      bubblewrap = {
        newSession = true; # NOTE: git diff
        # NOTE: ssh commit signing writes tmp files via $TMPDIR
        tmpfs = [ "/tmp" ];
        bind = {
          ro = [
            # NOTE: ssh-keygen getpwuid(), commit signing
            "/etc/passwd"
            (sloth.concat' sloth.homeDir "/.ssh")
            (sloth.env "_NIX_USER_BINS")
            "/run/current-system/sw/bin"
          ];
          rw = [
            (sloth.concat' sloth.xdgConfigHome "/git")
            (sloth.env "RW_ROOT")
            # git EDITOR
            (sloth.concat' sloth.xdgConfigHome "/nvim")
            (sloth.concat' sloth.xdgStateHome "/nvim")
            (sloth.concat' sloth.xdgDataHome "/nvim")
            (sloth.concat' sloth.xdgCacheHome "/nvim")
          ];
        };
      };
    };
  };
in
pkgs.writeShellScriptBin "git" ''
  err() {
    : "''${1:?}"

    printf "\033[31;1mnixpak-git: %b\033[0m\n" "$1" 1>&2
  }

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
''
