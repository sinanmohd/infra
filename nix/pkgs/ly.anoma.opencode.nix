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

  opencode = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkgs.opencode;
      etc.sslCertificates.enable = true;

      bubblewrap = {
        network = true;
        newSession = true;
        bind = {
          ro = [
            (sloth.concat' sloth.xdgConfigHome "/git/config")
            (sloth.env "_NIX_USER_BINS")
            "/run/current-system/sw/bin"
          ];
          rw = [
            # NOTE: main dev environment
            (sloth.env "RW_ROOT")
            # NOTE: agent kubeconfig
            (sloth.concat' sloth.homeDir "/.kube/agent.config")
            # NOTE: caught from strace -f -e openat claude 2>&1 | grep -E "\.config|\.local|\.cache"
            (sloth.concat' sloth.xdgConfigHome "/opencode")
            (sloth.concat' sloth.xdgStateHome "/opencode")
            (sloth.concat' sloth.xdgDataHome "/opencode")
          ];
        };
      };
    };
  };
in
pkgs.writeShellScriptBin "opencode" ''
  err() {
    : "''${1:?}"

    printf "\033[31;1mnixpak-opencode: %b\033[0m\n" "$1" 1>&2
  }

  # NOTE: allows access to user bin
  export _NIX_USER_BINS="/etc/profiles/per-user/$USER/bin"

  # NOTE: RBAC isolated agent k8s access
  export KUBECONFIG="$HOME/.kube/agent.config"

  if [ -z "$RW_ROOT" ]; then
    if ! rw_root="$(${lib.getExe git} rev-parse --show-toplevel 2>/dev/null)"; then
      err "Not inside a git repository. Please navigate to a git repository or manually set \$RW_ROOT."
      exit 1
    fi

    case "$rw_root" in
    "$HOME/"*) ;;
    "$HOME")
      err "The repository root is your \$HOME directory. This is usually a mistake and could be destructive. To override, manually set \$RW_ROOT."
      exit 1
      ;;
    *)
      err "The repository root is outside your \$HOME directory. This is usually a mistake and could be destructive. To override, manually set \$RW_ROOT."
      exit 1
      ;;
    esac

    export RW_ROOT="$rw_root"
  fi

  exec ${lib.getExe opencode.config.script}
''
