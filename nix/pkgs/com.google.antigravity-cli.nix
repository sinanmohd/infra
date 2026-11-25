{
  lib,
  pkgs,
  nixpak,
  git,
  libSinan,
}:
let
  pkg_raw = pkgs.antigravity-cli;
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkgs.writeShellScriptBin "fake_tty" ''
        exec ${pkgs.util-linux}/bin/script --quiet --return /dev/null -- ${lib.getExe pkg_raw} "$@"
      '';
      imports = [ nixpak.nixpakModules.network ];

      # NOTE: allow hooks access to notify-send
      dbus.policies."org.freedesktop.Notifications" = "talk";
      # NOTE: google oauth login opens the browser through the host portal
      dbus.rules.call."org.freedesktop.portal.Desktop" = [
        "org.freedesktop.portal.OpenURI.*@/org/freedesktop/portal/desktop"
        "org.freedesktop.DBus.Introspectable.Introspect@/org/freedesktop/portal/desktop"
      ];

      bubblewrap = rec {
        newSession = true;
        # NOTE: microphone input
        sockets.pipewire = true;
        clearEnv = true;
        env = {
          # NOTE: binding the daemon socket makes /nix/var/nix a writable tmpfs,
          # so nix would pick a local store on its own
          NIX_REMOTE = "daemon";
          HOME = sloth.env "HOME";
          TERM = sloth.env "TERM";
          # NOTE:: nixpkgs xdg-open only looks for
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
            # NOTE: lets nix build into the real store through the daemon,
            # without it nix falls back to a store in the home directory, which
            # is a small tmpfs here
            "/nix/var/nix/daemon-socket"
            # NOTE: other programs that agent runs might use it
            [
              (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nixpak-antigravity-tmp"))
              "/tmp"
            ]
            # NOTE: main dev environment
            (sloth.env "RW_ROOT")
            # NOTE: [AGENT]: caught from strace -f -e openat agy 2>&1 | grep
            # -E "\.gemini|\.config|\.local|\.cache". State, settings, the
            # oauth token and skills are spread over ~/.gemini/antigravity-cli,
            # ~/.gemini/config and files directly under ~/.gemini (GEMINI.md)
            (sloth.mkdir (sloth.concat' sloth.homeDir "/.gemini"))
            (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/antigravity"))
          ];
          ro = [
            env.SOPS_AGE_KEY_FILE
            env.KUBECONFIG
            env.SSH_AUTH_SOCK
            (sloth.concat' sloth.homeDir "/.ssh/id_ed25519.pub")
            (sloth.concat' sloth.homeDir "/.ssh/known_hosts")
            # NOTE: ~/.ssh/config is a root owned nix store file, root
            # is nobody inside the user namespace and ssh refuses it ("Bad
            # owner"), bind a user owned copy instead
            [
              (sloth.env "NIXPAK_SSH_CONFIG")
              (sloth.concat' sloth.homeDir "/.ssh/config")
            ]
            "/etc/passwd"
            (sloth.concat' sloth.xdgConfigHome "/git/config")
            (sloth.env "NIXPAK_NIX_USER_BINS")
            "/run/current-system/sw/bin"
            # NOTE: microphone input
            [
              "/etc/static/alsa"
              "/etc/alsa"
            ]
            "/etc/localtime"
          ];
          # NOTE: allow nixos vm tests
          dev = [ "/dev/kvm" ];
        };
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit pkg_raw;
  pkg_nixpak = pkgs.writeShellScriptBin pkg_raw.meta.mainProgram ''
    err() {
      : "''${1:?}"

      printf "\033[31;1mnixpak-antigravity-cli: %b\033[0m\n" "$1" 1>&2
    }

    # NOTE: allows access to user bin
    export NIXPAK_NIX_USER_BINS="/etc/profiles/per-user/$USER/bin"

    # NOTE: user owned copy of ~/.ssh/config, see the bind
    export NIXPAK_SSH_CONFIG="$XDG_RUNTIME_DIR/nixpak-antigravity-ssh-config"
    rm -f "$NIXPAK_SSH_CONFIG"
    (umask 077 && cat "$HOME/.ssh/config" >"$NIXPAK_SSH_CONFIG")

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

    exec ${libSinan.nixpakWinch} ${
      libSinan.nixpakNamed { inherit nixpak pkg_raw; }
    } ${lib.getExe wrapped.config.script} "$@"
  '';
}
