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

  # NOTE: a nixpak script is a `#!launcher` script, so the process is named
  # "launcher" and that is what tmux and ps show. The kernel names a process
  # after the file it was exec'd as, so run the launcher through a symlink
  nixpakNamed =
    {
      runCommandLocal,
      callPackage,
      nixpak,
      pkg_raw,
    }:
    let
      name = pkg_raw.meta.mainProgram or pkg_raw.name;
      launcher = callPackage "${nixpak}/launcher" { };
    in
    "${
      runCommandLocal "nixpak-named-${name}" { } ''
        mkdir -p $out/bin
        ln -s ${launcher}/bin/launcher $out/bin/${name}
      ''
    }/bin/${name}";

  # NOTE: bwrap --new-session leaves the sandbox without a
  # controlling terminal, so the kernel never delivers SIGWINCH to it and
  # TUIs keep their startup size. This leaves a sidecar in the foreground
  # process group that relays SIGWINCH from the host side to the sessions
  nixpakWinch =
    {
      lib,
      writeShellScript,
      writeShellApplication,
      coreutils,
      procps,
    }:
    let
      # NOTE: a separate script, so runtimeInputs does not leak
      # into the PATH of the launcher and from there into the sandbox
      sidecar = writeShellApplication {
        name = "nixpak-winch-sidecar";
        runtimeInputs = [
          coreutils
          procps
        ];
        text = ''
          launcher="$1"
          sid="$(ps -o sid= -p "$$")"
          sid="$((sid))"

          # NOTE: walk down from the launcher while still in our
          # session, the first process in another session is the sandbox,
          # signal that session and do not descend into it
          forward() {
            ps -o pid=,sid= --ppid "$1" | while read -r pid psid; do
              if [ "$psid" = "$sid" ]; then
                forward "$pid"
              else
                pkill -WINCH -s "$psid" || :
              fi
            done || :
          }
          trap 'forward "$launcher"' WINCH

          # NOTE: returns when the launcher is gone, a trapped
          # SIGWINCH interrupts the wait, so go back to waiting
          tail --pid="$launcher" -f /dev/null &
          while kill -0 "$!" 2>/dev/null; do
            wait "$!" || :
          done
        '';
      };
    in
    writeShellScript "nixpak-winch" ''
      [ -t 0 ] || [ -t 1 ] || [ -t 2 ] || exec "$@"

      # NOTE: $$ becomes the launcher once it is exec'd. No tty or
      # pipe fds are kept, so readers of our stdout still see EOF when the
      # launcher exits. The launcher reaps every child before it exits, so
      # the sidecar is forked twice to not be one, else both would wait on
      # each other forever
      (${lib.getExe sidecar} "$$" </dev/null >/dev/null 2>&1 &)

      exec "$@"
    '';
}
