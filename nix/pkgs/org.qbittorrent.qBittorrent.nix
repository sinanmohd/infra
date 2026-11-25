{
  lib,
  pkgs,
  nixpak,
  libSinan,
}:
let
  pkg_raw = pkgs.qbittorrent;
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      # NOTE: share fonts with host
      fonts.enable = lib.mkForce false;

      app.package = pkg_raw;
      flatpak.appId = "org.qbittorrent.qBittorrent";

      imports = [
        nixpak.nixpakModules.gui-base
        nixpak.nixpakModules.network
      ];

      bubblewrap = {
        sockets = {
          x11 = false;
          wayland = true;
        };

        tmpfs = [
          "/tmp"
          "/dev/shm"
        ];

        # NOTE: the host QT_PLUGIN_PATH points into the user profile, which is
        # not visible in the sandbox, so qt6ct (QT_QPA_PLATFORMTHEME) breaks
        env.QT_PLUGIN_PATH = "${pkgs.qt6Packages.qt6ct}/lib/qt-6/plugins";

        bind = {
          rw = [
            (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/qBittorrent"))
            (sloth.mkdir (sloth.concat' sloth.xdgDataHome "/qBittorrent"))
            # TODO: xdgDownloadDir does not pick up ~/dl
            (sloth.concat' sloth.homeDir "/dl")
            sloth.xdgDownloadDir
          ];
          ro = [
            # NOTE: xdg user dirs
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.conf")
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.dirs")
            # NOTE: qt6ct settings and the wallust palette they point at, see
            # nix/home/modules/wayland/modules/sway/theme.nix
            (sloth.concat' sloth.xdgConfigHome "/qt6ct")
            (sloth.concat' sloth.xdgDataHome "/wallust")
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
        "org.kde.StatusNotifierWatcher" = "talk";
      };
    };
  };
in
libSinan.nixpakEnv {
  inherit pkg_raw;
  pkg_nixpak = wrapped.config.script;
}
