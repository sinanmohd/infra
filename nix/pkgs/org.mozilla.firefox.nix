{
  lib,
  pkgs,
  nixpak,
  buildEnv,
  libSinan,
  extraPolicies ? { },
  cfg ? { },
  pkcs11Modules ? [ ],
}:
let
  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkgs.firefox.override (old: {
        # NOTE: used by home-manager module
        cfg = old.cfg or { } // cfg;
        extraPolicies = (old.extraPolicies or { }) // extraPolicies;
        pkcs11Modules = (old.pkcs11Modules or [ ]) ++ pkcs11Modules;
      });
      flatpak.appId = "org.mozilla.firefox";

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

        tmpfs = [
          # NOTE: caught from strace -f -e openat firefox
          "/tmp"
          "/dev/shm"
        ];

        bind = {
          rw = [
            (sloth.concat' sloth.homeDir "/.mozilla")
            (sloth.concat' sloth.xdgConfigHome "/mozilla")
            (sloth.concat' sloth.xdgCacheHome "/mozilla")
            # NOTE: xdg user dirs
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.conf")
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.dirs")
            # TODO: xdgDownloadDir does not pick up ~/dl
            (sloth.concat' sloth.homeDir "/dl")
            sloth.xdgDownloadDir
            # NOTE: pywal support
            (sloth.concat' sloth.xdgCacheHome "/wal/colors.json")
          ];
          ro = [
            "/sys/bus/pci"
            # NOTE: caught from strace -f -e openat firefox
            "/etc/localtime"
            "/etc/zoneinfo"
          ];
        };
      };

      dbus.policies = {
        "org.mozilla.firefox.*" = "own";
        "org.mpris.MediaPlayer2.firefox.*" = "own";
        "org.gnome.Shell.Screencast" = "talk";
        "org.freedesktop.Notifications" = "talk";
      };

    };
  };
in
libSinan.nixpakEnv {
  inherit buildEnv;
  pkg_raw = pkgs.firefox;
  pkg_nixpak = wrapped.config.script;
}
