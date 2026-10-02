{
  lib,
  pkgs,
  nixpak,
  git,
  buildEnv,
  libSinan,
  # NOTE: useful to ship sandboxed neovim distro, so users can just $ nix run
  extraBins ? [ ],
  configPath ? null,
}:
let
  pkg_raw = pkgs.neovim;
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  nvimBins = buildEnv {
    name = "neovim-bin";
    paths =
      with pkgs;
      [
        tmux
        bash
        git
      ]
      ++ extraBins;
    pathsToLink = [ "/bin" ];
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkg_raw;

      imports = [ nixpak.nixpakModules.network ];

      bubblewrap = {
        newSession = true;
        clearEnv = true;
        env = {
          HOME = sloth.env "HOME";
          TERM = sloth.env "TERM";
          # NOTE: tmux inherits envs from sandbox
          PATH = sloth.env "PATH";
          # NOTE: tmux passthrough
          TMUX = sloth.envOr "TMUX" "";
          TMUX_PANE = sloth.envOr "TMUX_PANE" "";
          TMUX_TMPDIR = "TMUX_TMPDIR";
        };
        bind = {
          rw = [
            (sloth.env "RW_ROOT")
            (sloth.concat' sloth.xdgStateHome "/nvim")
            (sloth.concat' sloth.xdgDataHome "/nvim")
            (sloth.concat' sloth.xdgCacheHome "/nvim")
          ];
          ro = [
            (sloth.concat' sloth.xdgConfigHome "/nvim")
            (sloth.concat' sloth.xdgConfigHome "/git/config")
            (sloth.concat' sloth.xdgConfigHome "/tmux")
            (sloth.env "TMUX_TMPDIR")
            (sloth.env "SHELL")
          ];
        };
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit buildEnv pkg_raw;
  pkg_nixpak = pkgs.writeShellScriptBin "nvim" ''
    export PATH="$PATH:${nvimBins}/bin"

    if [ -z "$TMUX_TMPDIR" ]; then
      tmux_socket="''${TMUX%%,*}"
      export TMUX_TMPDIR="''${tmux_socket%/*}"
    fi
    if [ -z "$TMUX_TMPDIR" ]; then
      export TMUX_TMPDIR="/run/user/$(id -u)/tmux-$(id -u)"
    fi

    if [ -z "$RW_ROOT" ]; then
      if rw_root="$(${lib.getExe git} rev-parse --show-toplevel 2>/dev/null)"; then
        export RW_ROOT="$rw_root"
      else
        export RW_ROOT="$PWD"
      fi
    fi

    exec ${lib.getExe wrapped.config.script} ${
      if configPath != null then "-u ${configPath}" else ""
    } "$@"
  '';
}
