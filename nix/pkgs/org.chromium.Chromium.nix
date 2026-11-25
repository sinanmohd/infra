{
  lib,
  pkgs,
  nixpak,
  libSinan,
  commandLineArgs ? "",
  policies ? { },
}:
let
  # NOTE: used by home-manager module
  pkg_raw = pkgs.chromium.override { inherit commandLineArgs; };
  policiesDir = pkgs.writeTextDir "managed/policies.json" (builtins.toJSON policies);
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      # NOTE: share fonts with host
      fonts.enable = lib.mkForce false;

      app.package = pkg_raw;
      flatpak.appId = "org.chromium.Chromium";

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

        tmpfs = [ "/dev/shm" ];

        bind = {
          rw = [
            # NOTE: ~/.config/chromium/SingletonSocket is a symlink into /tmp
            [
              (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nixpak-chromium-tmp"))
              "/tmp"
            ]
            (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/chromium"))
            # TODO: xdgDownloadDir does not pick up ~/dl
            (sloth.concat' sloth.homeDir "/dl")
            sloth.xdgDownloadDir
          ];
          ro = [
            [
              "${policiesDir}"
              "/etc/chromium/policies"
            ]
            # NOTE: xdg user dirs
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.conf")
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.dirs")
            # NOTE: gtk theme and the wallust colors it imports, see
            # nix/home/modules/wayland/modules/sway/theme.nix
            (sloth.concat' sloth.xdgDataHome "/themes")
            (sloth.concat' sloth.xdgDataHome "/wallust")
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
        "org.mpris.MediaPlayer2.chromium.*" = "own";
        "org.gnome.Shell.Screencast" = "talk";
        "org.freedesktop.secrets" = "talk";
        "org.freedesktop.Notifications" = "talk";
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit pkg_raw;
  pkg_nixpak = wrapped.config.script;
}
