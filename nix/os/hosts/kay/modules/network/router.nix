{ ... }:
let
  wanInterface = "ppp0";

  gponInterface = "enp3s0";
  gponHost = "192.168.38.1";
  gponPrefix = 24;

  lanInterface_1 = "enp11s0f3u2c2";
  lanBridgeInterface = "lan";
  lanPrefix = 24;
  lanHost = "192.168.43.1";

  # lanWapMac = "40:86:cb:d7:40:49";
  # lanWapIp = "192.168.43.2";
in
{
  systemd.network = {
    enable = true;
    netdevs = {
      "20-${lanBridgeInterface}" = {
        netdevConfig = {
          Kind = "bridge";
          Name = lanBridgeInterface;
        };
      };
    };
    networks = {
      "30-${lanInterface_1}" = {
        matchConfig.Name = lanInterface_1;
        networkConfig.Bridge = lanBridgeInterface;
      };
      "40-${lanBridgeInterface}" = {
        matchConfig.Name = lanBridgeInterface;
        linkConfig.RequiredForOnline = "routable";
        networkConfig = {
          Address = "${lanHost}/${toString lanPrefix}";
          DHCPServer = true;
          IPv6Forwarding = true;
          IPv4Forwarding = true;
        };
        dhcpServerConfig = {
          PoolOffset = 100;
          DNS = "_server_address";
        };
      };
      "40-${gponInterface}" = {
        matchConfig.Name = gponInterface;
        networkConfig.Address = "${gponHost}/${toString gponPrefix}";
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };
  networking = {
    nat = {
      enable = true;
      externalInterface = wanInterface;
      internalInterfaces = [ lanBridgeInterface ];
    };
    firewall = {
      allowedUDPPorts = [
        53
        67
      ];
      allowedTCPPorts = [ 53 ];
      extraCommands = ''
        iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
            -o ${wanInterface} \
            -j TCPMSS --clamp-mss-to-pmtu
      '';
      extraStopCommands = ''
        iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN \
            -o ${wanInterface} \
            -j TCPMSS --clamp-mss-to-pmtu
      '';
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve.DNSStubListenerExtra = lanHost;
  };
}
