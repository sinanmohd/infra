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
  winch = pkgs.callPackage libSinan.nixpakWinch { };
  named = pkgs.callPackage libSinan.nixpakNamed {
    inherit nixpak pkg_raw;
  };
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      imports = [ nixpak.nixpakModules.network ];

      # NOTE: allow hooks access to notify-send
      dbus.policies."org.freedesktop.Notifications" = "talk";
      # NOTE: login host portal (OpenURI)
      dbus.rules.call."org.freedesktop.portal.Desktop" = [
        "org.freedesktop.portal.OpenURI.*@/org/freedesktop/portal/desktop"
        "org.freedesktop.DBus.Introspectable.Introspect@/org/freedesktop/portal/desktop"
      ];

      app.package = pkgs.writeShellScriptBin "fake_tty" ''
        exec ${pkgs.util-linux}/bin/script --quiet --return /dev/null -- ${lib.getExe pkg_raw} "$@"
      '';

      bubblewrap = rec {
        newSession = true;
        # NOTE: /voice support
        sockets.pipewire = true;
        clearEnv = true;
        env = {
          CLAUDE_CONFIG_DIR = sloth.env "CLAUDE_CONFIG_DIR";
          HOME = sloth.env "HOME";
          TERM = sloth.env "TERM";
          # NOTE: nixpkgs xdg-open only looks for
          # $XDG_RUNTIME_DIR/flatpak-info, nixpak writes /.flatpak-info
          NIXOS_XDG_OPEN_USE_PORTAL = "1";
          # NOTE: nixpak inside nixpak hard
          PATH = sloth.concat [
            "${pkgs.git}/bin:"
            (sloth.env "PATH")
          ];
          # NOTE: isolated agent access
          SOPS_AGE_KEY_FILE = (sloth.concat' sloth.xdgConfigHome "/sops/age/agent.keys.txt");
          KUBECONFIG = (sloth.concat' sloth.homeDir "/.kube/agent.config");
          # NOTE: ssh commit signing through the agent, the private key outside
          SSH_AUTH_SOCK = (sloth.concat' sloth.runtimeDir "/ssh-agent");
        };

        bind = {
          rw = [
            # NOTE: claude code scratchpad, other programs that agent runs
            [
              (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nixpak-claude-tmp"))
              "/tmp"
            ]
            (sloth.mkdir (sloth.env "CLAUDE_CONFIG_DIR"))
            (sloth.concat' sloth.homeDir "/.claude.json")
            # NOTE: main dev environment
            (sloth.env "RW_ROOT")
            # NOTE: caught from strace -f -e openat claude 2>&1 | grep -E "\.config|\.local|\.cache"
            (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/anthropic"))
            (sloth.mkdir (sloth.concat' sloth.xdgCacheHome "/claude-cli-nodejs"))
          ];
          ro = [
            env.SOPS_AGE_KEY_FILE
            env.KUBECONFIG
            env.SSH_AUTH_SOCK
            (sloth.concat' sloth.homeDir "/.ssh/id_ed25519.pub")
            (sloth.concat' sloth.homeDir "/.ssh/known_hosts")
            # NOTE: ~/.ssh/config is a root owned nix store file, root is nobody
            # inside the user namespace and ssh refuses it ("Bad owner"), bind a
            # user owned copy instead
            [
              (sloth.env "_SSH_CONFIG")
              (sloth.concat' sloth.homeDir "/.ssh/config")
            ]
            "/etc/passwd"
            (sloth.concat' sloth.xdgConfigHome "/git/config")
            (sloth.env "_NIX_USER_BINS")
            "/run/current-system/sw/bin"
            # NOTE: hook commands are spawned via a hardcoded /bin/sh
            "/bin/sh"
            # NOTE: /voice support
            [
              "/etc/static/alsa"
              "/etc/alsa"
            ]
          ];
          # NOTE: allow nixos vm tests
          dev = [ "/dev/kvm" ];
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

    # NOTE: allows access to user bin
    export _NIX_USER_BINS="/etc/profiles/per-user/$USER/bin"

    # NOTE: user owned copy of ~/.ssh/config, see the bind
    export _SSH_CONFIG="$XDG_RUNTIME_DIR/nixpak-claude-ssh-config"
    rm -f "$_SSH_CONFIG"
    (umask 077 && cat "$HOME/.ssh/config" >"$_SSH_CONFIG")

    export CLAUDE_CONFIG_DIR="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    # NOTE: inconsistency when setting $CLAUDE_CONFIG_DIR
    if [ -f "$HOME/.claude.json" ] && [ ! -f "$CLAUDE_CONFIG_DIR/.claude.json" ]; then
      mv "$HOME/.claude.json" "$CLAUDE_CONFIG_DIR/.claude.json"
    fi

    if [ -z "$RW_ROOT" ]; then
      if ! rw_root="$(${lib.getExe git} rev-parse --show-toplevel 2>/dev/null)"; then
        # NOTE: outside a git repo, fall back to the downloads dir
        rw_root="$(${pkgs.xdg-user-dirs}/bin/xdg-user-dir DOWNLOAD)"
        mkdir -p "$rw_root"
        cd "$rw_root" || exit 1
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

    exec ${winch} ${named} ${lib.getExe wrapped.config.script} "$@"
  '';
}
