{
  lib,
  pkgs,
  nixpak,
  git,
  libSinan,
  buildEnv,
}:
let
  pkg_raw = pkgs.claude-code;
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      imports = [ nixpak.nixpakModules.network ];

      app.package = pkgs.writeShellScriptBin "fake_tty" ''
        exec ${pkgs.util-linux}/bin/script --quiet --return /dev/null -- ${lib.getExe pkg_raw} "$@"
      '';

      bubblewrap = rec {
        newSession = true;

        # NOTE: even if claude does not need this, other programs that agent
        # runs will need this
        tmpfs = [ "/tmp" ];

        clearEnv = true;
        env = {
          CLAUDE_CONFIG_DIR = sloth.env "CLAUDE_CONFIG_DIR";
          HOME = sloth.env "HOME";
          TERM = sloth.env "TERM";
          # NOTE: nixpak inside nixpak hard
          PATH = sloth.concat [
            "${pkgs.git}/bin:"
            (sloth.env "PATH")
          ];
          # NOTE: isolated agent access
          SOPS_AGE_KEY_FILE = (sloth.concat' sloth.xdgConfigHome "/sops/age/agent.keys.txt");
          KUBECONFIG = (sloth.concat' sloth.homeDir "/.kube/agent.config");
        };

        bind = {
          rw = [
            (sloth.env "CLAUDE_CONFIG_DIR")
            (sloth.concat' sloth.homeDir "/.claude.json")
            (sloth.env "_CLAUDE_SCRATCHPAD")
            # NOTE: main dev environment
            (sloth.env "RW_ROOT")
            # NOTE: caught from strace -f -e openat claude 2>&1 | grep -E "\.config|\.local|\.cache"
            (sloth.concat' sloth.xdgConfigHome "/anthropic")
            (sloth.concat' sloth.xdgCacheHome "/claude-cli-nodejs")
            # NOTE: isolated agent access
          ];
          ro = [
            env.SOPS_AGE_KEY_FILE
            env.KUBECONFIG
            (sloth.concat' sloth.xdgConfigHome "/git/config")
            (sloth.env "_NIX_USER_BINS")
            "/run/current-system/sw/bin"
            # TODO: comma fails withoout this, but `nix run` does not ?
            "/nix/var/nix"
          ];
        };
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit buildEnv pkg_raw;
  pkg_nixpak = pkgs.writeShellScriptBin "claude" ''
    err() {
      : "''${1:?}"

      printf "\033[31;1mnixpak-claude-code: %b\033[0m\n" "$1" 1>&2
    }

    export _CLAUDE_SCRATCHPAD="/tmp/claude-$(id -u)"
    # NOTE: allows access to user bin
    export _NIX_USER_BINS="/etc/profiles/per-user/$USER/bin"

    export CLAUDE_CONFIG_DIR="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    # NOTE: inconsistency when setting $CLAUDE_CONFIG_DIR
    if [ -f "$HOME/.claude.json" ] && [ ! -f "$CLAUDE_CONFIG_DIR/.claude.json" ]; then
      mv "$HOME/.claude.json" "$CLAUDE_CONFIG_DIR/.claude.json"
    fi

    if [ -z "$RW_ROOT" ]; then
      if ! rw_root="$(${lib.getExe git} rev-parse --show-toplevel 2>/dev/null)"; then
        err "Not inside a git repo. Please navigate to a git repository or manually set \$RW_ROOT."
        exit 1
      fi

      case "$rw_root" in
      "$HOME/"*) ;;
      "$HOME")
        err "The repo root is your \$HOME directory. This is usually a mistake and could be destructive. To override, manually set \$RW_ROOT."
        exit 1
        ;;
      *)
        err "The repo root is outside your \$HOME directory. This is usually a mistake and could be destructive. To override, manually set \$RW_ROOT."
        exit 1
        ;;
      esac

      export RW_ROOT="$rw_root"
    fi

    exec ${lib.getExe wrapped.config.script} "$@"
  '';
}
