{ config, pkgs, ... }:
let
  email = config.global.userdata.email;
  domain = config.global.userdata.domain;

  environmentFile = pkgs.writeText "acme-dns" "RFC2136_NAMESERVER='[2001:470:ee65::1]:53'";
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = email;

    certs.${domain} = {
      inherit domain;
      extraDomainNames = [ "*.${domain}" ];

      dnsProvider = "rfc2136";
      dnsPropagationCheck = false; # local DNS server

      inherit environmentFile;
      group = config.services.nginx.group;
    };
  };
}
