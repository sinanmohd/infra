{
  config,
  pkgs,
  lib,
  ...
}:

let
  iface = "hurricane";
  remote = "216.218.221.42";

  clinet = "2001:470:35:72a::2";
  server = "2001:470:35:72a::1";

  prefix64 = "2001:470:36:72a::/64";
  prefix48 = "2001:470:ee65::/48";

  makeAddr =
    prefix: host:
    let
      split = lib.strings.splitString "/" prefix;
    in
    {
      address = "${lib.head split}${host}";
      prefixLength = lib.toInt (lib.last split);
    };
in
{
  networking = {
    sits.${iface} = {
      inherit remote;
      ttl = 225;
    };
    interfaces.${iface} = {
      mtu = 1472; # 1492(ppp0) - 20
      ipv6.addresses = [
        {
          address = clinet;
          prefixLength = 64;
        }

        (makeAddr prefix64 "1")
        (makeAddr prefix48 "1")
        (makeAddr prefix48 "1337")
      ];
    };

    iproute2 = {
      enable = true;
      rttablesExtraConfig = "200 hurricane";
    };

    firewall = {
      extraCommands = "iptables -A INPUT --proto 41 --source ${remote} --jump ACCEPT";
      extraStopCommands = "iptables -D INPUT --proto 41 --source ${remote} --jump ACCEPT";
    };
  };

  sops.secrets = {
    "hurricane/username".sopsFile = ./secrets.yaml;
    "hurricane/update_key".sopsFile = ./secrets.yaml;
    "hurricane/tunnel_id".sopsFile = ./secrets.yaml;
  };

  systemd.services."network-route-${iface}" = {
    description = "Routing configuration of ${iface}";
    wantedBy = [
      "network-setup.service"
      "network.target"
    ];
    before = [ "network-setup.service" ];
    bindsTo = [ "network-addresses-hurricane.service" ];
    after = [
      "network-pre.target"
      "network-addresses-hurricane.service"
    ];
    # restart rather than stop+start this unit to prevent the
    # network from dying during switch-to-configuration.
    stopIfChanged = false;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [ pkgs.iproute2 ];
    script = ''
      echo -n "adding route"

      ip -6 rule add from ${clinet}/64 table hurricane || exit 1
      ip -6 rule add from ${prefix64} table hurricane || exit 1
      ip -6 rule add from ${prefix48} table hurricane || exit 1

      ip -6 route add default via ${server} dev hurricane table hurricane || exit 1
    '';
    preStop = ''
      echo -n "deleting route"

      ip -6 route del default via ${server} dev hurricane table hurricane || exit 1

      ip -6 rule del from ${prefix48} table hurricane || exit 1
      ip -6 rule del from ${prefix64} table hurricane || exit 1
      ip -6 rule del from ${clinet}/64 table hurricane || exit 1
    '';
  };

  services.pppd.script."01-${iface}" = {
    runtimeInputs = with pkgs; [
      curl
      coreutils
      iproute2
      iputils
    ];
    text = ''
      wan_ip="$4"
      username="$(cat ${config.sops.secrets."hurricane/username".path})"
      update_key="$(cat ${config.sops.secrets."hurricane/update_key".path})"
      tunnel_id="$(cat ${config.sops.secrets."hurricane/tunnel_id".path})"

      auth_url="https://$username:$update_key@ipv4.tunnelbroker.net/nic/update?hostname=$tunnel_id"
      until curl --silent "$auth_url"; do
          sleep 1
      done

      while [ ! -e /sys/class/net/${iface} ]; do
          sleep 1 # make sure ${iface} is up
      done

      ip tunnel change ${iface} local "$wan_ip" mode sit
    '';
  };
}
