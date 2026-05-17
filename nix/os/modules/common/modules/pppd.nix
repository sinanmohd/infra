{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.pppd;
  shTypes = [
    "ip-up"
    "ip-down"
    "ipv6-up"
    "ipv6-down"
  ];
in
{
  meta = {
    maintainers = with maintainers; [ danderson ];
  };

  options.services.pppd = {
    enable = mkEnableOption (lib.mdDoc "pppd");

    package = mkOption {
      default = pkgs.ppp;
      defaultText = literalExpression "pkgs.ppp";
      type = types.package;
      description = lib.mdDoc "pppd package to use.";
    };

    config = mkOption {
      type = types.lines;
      default = "";
      description = lib.mdDoc "default config for pppd";
    };

    secret = {
      chap = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = lib.mdDoc "path to chap secret for pppd";
      };
      pap = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = lib.mdDoc "path to pap secret for pppd";
      };
      srp = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = lib.mdDoc "path to srp secret for pppd";
      };
    };

    script = mkOption {
      default = { };
      description = lib.mdoc ''
        script which is executed when the link is available for sending and
        receiving IP packets or when the link is no longer available for sending
        and receiving IP packets, see pppd(8) for more details
      '';
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              name = mkOption {
                type = types.str;
                default = name;
                example = "01-ddns.sh";
                description = lib.mdDoc "Name of the script.";
              };
              type = mkOption {
                default = "ip-up";
                type = types.enum shTypes;
                description = lib.mdDoc "Type of the script.";
              };
              text = mkOption {
                type = types.lines;
                default = "";
                description = lib.mdDoc "Shell commands to be executed.";
              };
              runtimeInputs = mkOption {
                type = types.listOf types.package;
                default = [ ];
                description = lib.mdDoc "dependencies of the shell script";
              };
            };
          }
        )
      );
    };

    peers = mkOption {
      default = { };
      description = lib.mdDoc "pppd peers.";
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              name = mkOption {
                type = types.str;
                default = name;
                example = "dialup";
                description = lib.mdDoc "Name of the PPP peer.";
              };

              enable = mkOption {
                type = types.bool;
                default = true;
                example = false;
                description = lib.mdDoc "Whether to enable this PPP peer.";
              };

              autostart = mkOption {
                type = types.bool;
                default = true;
                example = false;
                description = lib.mdDoc "Whether the PPP session is automatically started at boot time.";
              };

              config = mkOption {
                type = types.lines;
                default = "";
                description = lib.mdDoc "pppd configuration for this peer, see the pppd(8) man page.";
              };

              configFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                example = literalExpression "/run/secrets/ppp/peer/options";
                description = lib.mdDoc "pppd configuration file for this peer, see the pppd(8) man page.";
              };
            };
          }
        )
      );
    };
  };

  config =
    let
      enabledConfigs = filter (f: f.enable) (attrValues cfg.peers);

      defaultCfg =
        if (cfg.config != "") then
          {
            "ppp/options".text = cfg.config;
          }
        else
          { };

      mkPeers =
        peerCfg:
        with peerCfg;
        let
          key = if (configFile == null) then "text" else "source";
          val = if (configFile == null) then peerCfg.config else configFile;
        in
        {
          name = "ppp/peers/${name}";
          value.${key} = val;
        };

      enabledSh = filter (s: s.text != "") (attrValues cfg.script);
      mkMsh = name: {
        name = "ppp/${name}";
        value.mode = "0755";
        value.text = ''
          #!/bin/sh

          # see the pppd(8) man page
          for s in /etc/ppp/${name}.d/*.sh; do
              [ -x "$s" ] && "$s" "$@"
          done
        '';
      };
      mkUsh = shCfg: {
        name = "ppp/${shCfg.type}.d/${shCfg.name}.sh";
        value.mode = "0755";
        value.text = ''
          #!/bin/sh
          export PATH="${makeBinPath shCfg.runtimeInputs}:$PATH"

          ${shCfg.text}
        '';
      };

      enabledSec =
        let
          l = attrNames cfg.secret;
          f = (s: cfg.secret.${s} != null);
        in
        filter f l;
      mkSec = sec: {
        name = "ppp/${sec}-secrets";
        value.source = cfg.secret.${sec};
      };

      mkSystemd = peerCfg: {
        name = "pppd-${peerCfg.name}";
        value = {
          restartTriggers = [ config.environment.etc."ppp/peers/${peerCfg.name}".source ];
          before = [ "network.target" ];
          wants = [ "network.target" ];
          after = [ "network-pre.target" ];
          environment = {
            # pppd likes to write directly into /var/run. This is rude
            # on a modern system, so we use libredirect to transparently
            # move those files into /run/pppd.
            LD_PRELOAD = "${pkgs.libredirect}/lib/libredirect.so";
            NIX_REDIRECTS = "/var/run=/run/pppd";
          };
          serviceConfig =
            let
              capabilities = [
                "CAP_BPF"
                "CAP_SYS_TTY_CONFIG"
                "CAP_NET_ADMIN"
                "CAP_NET_RAW"
              ];
            in
            {
              ExecStart = "${getBin cfg.package}/sbin/pppd call ${peerCfg.name} nodetach nolog";
              Restart = "always";
              RestartSec = 5;

              AmbientCapabilities = capabilities;
              CapabilityBoundingSet = capabilities;
              KeyringMode = "private";
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              NoNewPrivileges = true;
              PrivateMounts = true;
              PrivateTmp = true;
              ProtectControlGroups = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectKernelModules = true;
              # pppd can be configured to tweak kernel settings.
              ProtectKernelTunables = false;
              ProtectSystem = "strict";
              RemoveIPC = true;
              RestrictAddressFamilies = [
                "AF_ATMPVC"
                "AF_ATMSVC"
                "AF_INET"
                "AF_INET6"
                "AF_IPX"
                "AF_NETLINK"
                "AF_PACKET"
                "AF_PPPOX"
                "AF_UNIX"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SecureBits = "no-setuid-fixup-locked noroot-locked";
              SystemCallFilter = "@system-service";
              SystemCallArchitectures = "native";

              # All pppd instances on a system must share a runtime
              # directory in order for PPP multilink to work correctly. So
              # we give all instances the same /run/pppd directory to store
              # things in.
              #
              # For the same reason, we can't set PrivateUsers=true, because
              # all instances need to run as the same user to access the
              # multilink database.
              RuntimeDirectory = "pppd";
              RuntimeDirectoryPreserve = true;
            };
          wantedBy = mkIf peerCfg.autostart [ "multi-user.target" ];
        };
      };

      etcFiles =
        listToAttrs (map mkPeers enabledConfigs)
        // listToAttrs (map mkMsh shTypes)
        // listToAttrs (map mkUsh enabledSh)
        // listToAttrs (map mkSec enabledSec)
        // defaultCfg;

      systemdConfigs = listToAttrs (map mkSystemd enabledConfigs);

    in
    mkIf cfg.enable {
      assertions = map (peerCfg: {
        assertion = (peerCfg.configFile == null || peerCfg.config == "");
        message = ''
          Please specify either
          'services.pppd.${peerCfg.name}.config' or
          'services.pppd.${peerCfg.name}.configFile'.
        '';
      }) enabledConfigs;

      environment.etc = etcFiles;
      systemd.services = systemdConfigs;
    };
}
