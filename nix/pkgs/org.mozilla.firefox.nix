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
      # NOTE: share fonts with host
      fonts.enable = lib.mkForce false;

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
          ];
          ro = [
            # NOTE: xdg user dirs
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.conf")
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.dirs")
            # NOTE: pywal support
            (sloth.concat' sloth.xdgCacheHome "/wal/colors.json")
            # NOTE: [AGENT]: only consumer is firefox/glxtest, which dlopens
            # libpci.so.3 (nixpkgs puts pciutils on LD_LIBRARY_PATH for this) and
            # scans /sys/bus/pci/devices to report PCI_VENDOR_ID/PCI_DEVICE_ID.
            # Used for gfx blocklist matching (WebRender, hw video decode),
            # about:support and telemetry -- not for render node selection,
            # which goes through libdrm via /sys/dev/char.
            # nixpak gui-base binds /sys/dev/char + /sys/devices/pci0000:00 for
            # libdrm, but not the /sys/bus/pci/devices enumeration dir libpci
            # needs. Without it glxtest warns and falls back to the Mesa-
            # reported ids (no fallback on the NVIDIA proprietary driver).
            "/sys/bus/pci"
            # NOTE: caught from strace -f -e openat firefox
            "/etc/localtime"
            # NOTE: fonts.enable = false, disables nixpak packaged font, now
            # fonts are shared with the host, this might break on non-nixos
            # systems
            "/etc/fonts"
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
