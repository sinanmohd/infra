{
  lib,
  pkgs,
  nixpak,
  git,
  buildEnv,
  libSinan,
}:
let
  pkg_raw = pkgs.git;
  serverBins = [
    "git-receive-pack"
    "git-upload-pack"
    "git-upload-archive"
  ];
  winch = pkgs.callPackage libSinan.nixpakWinch { };
  named = pkgs.callPackage libSinan.nixpakNamed {
    inherit nixpak pkg_raw;
  };
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app = {
        package = pkg_raw;
        extraEntrypoints = map (bin: "/bin/${bin}") serverBins;
      };

      # NOTE: CA bundle for https clone/fetch/push
      imports = [ nixpak.nixpakModules.network ];

      bubblewrap = rec {
        # NOTE: git diff
        newSession = true;
        # NOTE: ssh commit signing writes tmp files via $TMPDIR
        tmpfs = [ "/tmp" ];
        clearEnv = true;
        env = {
          HOME = sloth.env "HOME";
          TERM = sloth.envOr "TERM" "dumb";
          EDITOR = sloth.envOr "EDITOR" "vi";
          PATH = sloth.env "PATH";
          # NOTE: ssh commit signing through the agent, the private key outside
          SSH_AUTH_SOCK = (sloth.concat' sloth.runtimeDir "/ssh-agent");
        };
        bind = {
          rw = [
            (sloth.concat' sloth.homeDir "/.ssh/known_hosts")
            # NOTE: repo root
            (sloth.env "RW_ROOT")
          ];
          ro = [
            (sloth.concat' sloth.xdgConfigHome "/git")
            # NOTE: nix hook bins
            (sloth.env "_NIX_USER_BINS")
            "/run/current-system/sw/bin"
            # NOTE: ssh commit signing & push
            "/etc/passwd"
            env.SSH_AUTH_SOCK
            (sloth.concat' sloth.homeDir "/.ssh/id_ed25519.pub")
            # NOTE: ~/.ssh/config is a root owned nix store file, root is nobody
            # inside the user namespace and ssh refuses it ("Bad owner"), bind a
            # user owned copy instead
            [
              (sloth.env "_SSH_CONFIG")
              (sloth.concat' sloth.homeDir "/.ssh/config")
            ]
          ];
        };
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit buildEnv pkg_raw;
  pkg_nixpak = buildEnv {
    name = "${pkg_raw.pname}-nixpak";
    paths = [
      (pkgs.writeShellScriptBin "git" ''
        # NOTE: allows access to user bin
        export _NIX_USER_BINS="/etc/profiles/per-user/$USER/bin"

        # NOTE: user owned copy of ~/.ssh/config, git runs concurrently, so
        # write a temp file and rename it into place
        export _SSH_CONFIG="$XDG_RUNTIME_DIR/nixpak-git-ssh-config"
        ssh_config_tmp="$(${pkgs.coreutils}/bin/mktemp "$_SSH_CONFIG.XXXXXX")"
        ${pkgs.coreutils}/bin/cat "$HOME/.ssh/config" >"$ssh_config_tmp" 2>/dev/null
        ${pkgs.coreutils}/bin/mv -f "$ssh_config_tmp" "$_SSH_CONFIG"

        if [ -z "$RW_ROOT" ]; then
          if rw_root="$(${lib.getExe git} rev-parse --show-toplevel 2>/dev/null)"; then
            export RW_ROOT="$rw_root"
          else
            export RW_ROOT="$PWD"
          fi
        fi

        exec ${winch} ${named} ${lib.getExe wrapped.config.script} "$@"
      '')
    ]
    # NOTE: [AGENT]: server side helpers invoked over ssh (git push/fetch),
    # the repo path is always the last arg
    ++ map (
      bin:
      pkgs.writeShellScriptBin bin ''
        export _NIX_USER_BINS="/etc/profiles/per-user/$USER/bin"

        if [ -z "$RW_ROOT" ]; then
          if rw_root="$(${pkgs.coreutils}/bin/realpath -e -- "''${!#}" 2>/dev/null)"; then
            export RW_ROOT="$rw_root"
          else
            export RW_ROOT="$PWD"
          fi
        fi

        exec ${wrapped.config.env}/bin/${bin} "$@"
      ''
    ) serverBins;
  };
}
