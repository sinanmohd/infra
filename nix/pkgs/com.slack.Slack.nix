{
  lib,
  pkgs,
  nixpak,
  libSinan,
  policies ? { },
}:
let
  # NOTE: hardcoded desktop entry execs slack by its store path
  pkg_raw = pkgs.slack.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      substituteInPlace $out/share/applications/slack.desktop \
        --replace-fail "Exec=$out/bin/slack" "Exec=slack"
    '';
  });

  policiesFile = pkgs.writeText "slack-desktop.conf" (builtins.toJSON policies);

  mkNixPak = nixpak.lib.nixpak {
    inherit lib pkgs;
  };

  wrapped = mkNixPak {
    config = { sloth, pkgs, ... }: {
      app.package = pkg_raw;
      flatpak.appId = "com.slack.Slack";

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
          NIXOS_OZONE_WL = "1";
        };

        tmpfs = [ "/dev/shm" ];

        bind = {
          rw = [
            [
              (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nixpak-slack-tmp"))
              "/tmp"
            ]
            (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/Slack"))
          ]
          ++ (
            if policies ? DownloadPath then
              [ policies.DownloadPath ]
            else
              [
                # TODO: xdgDownloadDir does not pick up ~/dl, same as chromium
                (sloth.concat' sloth.homeDir "/dl")
                sloth.xdgDownloadDir
              ]
          );
          ro = [
            [
              "${policiesFile}"
              "/etc/slack-desktop.conf"
            ]
            # NOTE: chromium gpu process enumerates pci devices for
            # its gpu blocklist
            "/sys/bus/pci"
            "/etc/localtime"
            # NOTE: slack reads the distro info at boot and hangs if not found
            "/etc/os-release"
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
  inherit pkg_raw;
  pkg_nixpak = wrapped.config.script;
}
