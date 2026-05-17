{ config, pkgs, ... }:
let
  listen_addr = [
    "137.59.84.126"
    "127.0.0.153"
    "2001:470:ee65::1"
  ];

  acmeSOA = pkgs.writeText "acmeSOA" ''
    $TTL 2d

    @	IN	SOA	ns1.sinanmohd.com.	sinan.sinanmohd.com. (
                        2024020505 ; serial
                        2h         ; refresh
                        5m         ; retry
                        1d         ; expire
                        5m )       ; nx ttl

        IN	NS	ns1.sinanmohd.com.
  '';
in
{
  imports = [ ./ddns.nix ];

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  sops.secrets.dns = {
    owner = config.systemd.services.knot.serviceConfig.User;
    group = config.systemd.services.knot.serviceConfig.Group;
    sopsFile = ./secrets.yaml;
  };

  services.knot = {
    enable = true;
    keyFiles = [ config.sops.secrets.dns.path ];

    settings = {
      server.listen = listen_addr;

      remote = [
        {
          id = "ns1.he.net";
          address = [
            "216.218.130.2"
            "2001:470:100::2"
          ];
          via = "137.59.84.126";
        }
        {
          id = "m.gtld-servers.net";
          address = [
            "2001:501:b1f9::30"
            "192.55.83.30"
          ];
        }
      ];

      submission = [
        {
          id = "gtld-servers.net";
          parent = "m.gtld-servers.net";
        }
      ];

      policy = [
        {
          id = "gtld-servers.net";
          algorithm = "ecdsap384sha384";
          ksk-lifetime = "365d";
          ksk-submission = "gtld-servers.net";
        }
      ];

      # generate TSIG key with keymgr -t name
      acl = [
        {
          id = "ns1.he.net";
          key = "ns1.he.net";
          address = [
            "2001:470:600::2"
            "216.218.133.2"
          ];
          action = "transfer";
        }
        {
          id = "ddns";
          address = listen_addr;
          update-type = [
            "A"
            "AAAA"
          ];
          action = "update";
        }
        {
          id = "acme";
          address = listen_addr;
          update-type = [ "TXT" ];
          action = "update";
        }
      ];

      mod-rrl = [
        {
          id = "default";
          rate-limit = 200;
          slip = 2;
        }
      ];

      template = [
        {
          id = "default";
          semantic-checks = "on";
          global-module = "mod-rrl/default";
        }
        {
          id = "master";
          semantic-checks = "on";

          dnssec-signing = "on";
          dnssec-policy = "gtld-servers.net";

          notify = [ "ns1.he.net" ];
          acl = [
            "ns1.he.net"
            "ddns"
          ];

          zonefile-sync = "-1";
          zonefile-load = "difference";
        }
        {
          id = "acme";
          semantic-checks = "on";
          acl = [ "acme" ];

          zonefile-sync = "-1";
          zonefile-load = "difference";
          journal-content = "changes";
        }
      ];

      zone = [
        {
          domain = "sinanmohd.com";
          file = ./sinanmohd.com.zone;
          template = "master";
        }
        {
          domain = "_acme-challenge.sinanmohd.com";
          file = acmeSOA;
          template = "acme";
        }
        {
          domain = "5.6.e.e.0.7.4.0.1.0.0.2.ip6.arpa";
          file = ./5.6.e.e.0.7.4.0.1.0.0.2.ip6.arpa.zone;
        }
      ];
    };
  };
}
