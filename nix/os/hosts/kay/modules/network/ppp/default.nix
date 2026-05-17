{ config, pkgs, ... }:

let
  inetVlan = 1003;
  wanInterface = "enp3s0";
  vlanInterface = "wan";
in
{
  sops.secrets = {
    "ppp/chap-secrets".sopsFile = ./secrets.yaml;
    "ppp/pap-secrets".sopsFile = ./secrets.yaml;
    "ppp/username".sopsFile = ./secrets.yaml;
  };

  systemd.network = {
    enable = true;
    netdevs."20-vlan-${toString inetVlan}" = {
      netdevConfig = {
        Kind = "vlan";
        Name = vlanInterface;
      };
      vlanConfig.Id = inetVlan;
    };
    networks = {
      "30-${wanInterface}" = {
        matchConfig.Name = wanInterface;
        networkConfig = {
          LinkLocalAddressing = "no";
          VLAN = vlanInterface;
        };
        linkConfig.RequiredForOnline = "carrier";
      };
      "30-${vlanInterface}" = {
        matchConfig.Name = vlanInterface;
        networkConfig.LinkLocalAddressing = "no";
        linkConfig.RequiredForOnline = "carrier";
      };
    };
  };

  networking.tempAddresses = "disabled";

  services.pppd = {
    enable = true;
    config = ''
      plugin pppoe.so
      debug

      nic-wan
      defaultroute
      ipv6 ::1337,
      noauth

      persist
      lcp-echo-adaptive
      lcp-echo-interval 1
      lcp-echo-failure 5
    '';
    script."01-ipv6-ra" = {
      type = "ip-up";
      runtimeInputs = [ pkgs.procps ];

      text = ''
        sysctl net.ipv6.conf.ppp0.accept_ra=2
      '';
    };
    peers.keralavision = {
      enable = true;
      autostart = true;
      configFile = config.sops.secrets."ppp/username".path;
    };
    secret = {
      chap = config.sops.secrets."ppp/chap-secrets".path;
      pap = config.sops.secrets."ppp/pap-secrets".path;
    };
  };
}
