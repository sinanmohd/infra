{
  lib,
  pkgs,
  nixpak,
}:
let
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  claude-code = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkgs.claude-code;
      etc.sslCertificates.enable = true;

      bubblewrap = {
        network = true;
        newSession = true;
        bind = {
          ro = [
            (sloth.concat' sloth.xdgConfigHome "/git/config")
            (sloth.env "_NIXPAK_USER_NIX_BIN")
            "/run/current-system/sw/bin"
          ];
          rw = [
            (sloth.env "CLAUDE_CONFIG_DIR")
            (sloth.concat' sloth.homeDir "/.claude.json")
            # NOTE: main dev environment
            (sloth.concat' sloth.homeDir "/dev")
            # NOTE: agent kubeconfig
            (sloth.concat' sloth.homeDir "/.kube/agent.config")
            # NOTE: caught from strace -f -e openat claude 2>&1 | grep -E "\.config|\.local|\.cache"
            (sloth.concat' sloth.xdgConfigHome "/anthropic")
            (sloth.concat' sloth.xdgCacheHome "/claude-cli-nodejs")
          ];
        };
      };
    };
  };
in
pkgs.writeShellScriptBin "claude" ''
  # NOTE: allows access to all bins
  export CLAUDE_CONFIG_DIR="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  export _NIXPAK_USER_NIX_BIN="/etc/profiles/per-user/$USER/bin"

  # NOTE: RBAC isolated agent k8s access
  export KUBECONFIG="$HOME/.kube/agent.config"

  # NOTE: inconsistency when setting CLAUDE_CONFIG_DIR
  if [ -f "$HOME/.claude.json" ] && [ ! -f "$CLAUDE_CONFIG_DIR/.claude.json" ]; then
    mv "$HOME/.claude.json" "$CLAUDE_CONFIG_DIR/.claude.json"
  fi

  exec ${lib.getExe claude-code.config.script}
''
