{
  lib,
  pkgs,
  nixpak,
  buildEnv,
  libSinan,
}:
let
  # NOTE: hot reload custom_themes from config.json, Patches the built app.asar
  # instead of the source to avoid rebuilding element
  pkg_raw =
    let
      element = pkgs.element-desktop;
    in
    pkgs.runCommand element.name
      {
        inherit (element) pname version meta;
        nativeBuildInputs = [ pkgs.asar ];
      }
      ''
        cp -a ${element} $out
        chmod -R u+w $out

        asar extract $out/share/element/app.asar app
        cp ${./custom-themes-reload.js} app/lib/custom-themes-reload.js
        sed -i '1i import "./custom-themes-reload.js";' app/lib/electron-main.js
        asar pack app $out/share/element/app.asar

        substituteInPlace $out/bin/element-desktop \
          --replace-fail ${element} $out
      '';

  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      # NOTE: share fonts with host
      fonts.enable = lib.mkForce false;

      app.package = pkg_raw;
      flatpak.appId = "im.riot.Riot";

      imports = [
        nixpak.nixpakModules.gui-base
        nixpak.nixpakModules.network
      ];

      bubblewrap = {
        sockets = {
          x11 = false;
          wayland = true;
          pipewire = true;
        };

        env = {
          NIXOS_XDG_OPEN_USE_PORTAL = "1";
          PATH = sloth.concat [
            "${pkgs.xdg-utils}/bin:"
            (sloth.env "PATH")
          ];
        };

        # NOTE: from strace -f -e openat element-desktop 2>&1 | grep -E "/dev/shm|/tmp"
        tmpfs = [
          "/tmp"
          "/dev/shm"
        ];

        bind = {
          rw = [
            (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/Element"))
          ];
          ro = [
            # NOTE: xdg user dirs
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.conf")
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.dirs")
            # NOTE: [AGENT]: chromium gpu process enumerates pci devices for
            # its gpu blocklist, same as firefox/glxtest
            "/sys/bus/pci"
            "/etc/localtime"
            # NOTE: fonts.enable = false, disables nixpak packaged font, now
            # fonts are shared with the host, this might break on non-nixos
            # systems
            "/etc/fonts"
          ];
        };
      };

      dbus.policies = {
        "org.freedesktop.Notifications" = "talk";
        "org.freedesktop.secrets" = "talk";
        "org.kde.StatusNotifierWatcher" = "talk";
        "org.mpris.MediaPlayer2.chromium.*" = "own";
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit buildEnv pkg_raw;
  pkg_nixpak = wrapped.config.script;
}
