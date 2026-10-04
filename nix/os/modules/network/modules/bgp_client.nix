{ config, lib, ... }:
let
  cfg = config.sinan.bgp.client;
in
{
  options.sinan.bgp.client = {
    enable = lib.mkEnableOption "bgp client";
    ipUnderlayV4 = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Underlay IPv4 addresses";
    };
    ipUnderlayV6 = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Underlay IPv6 addresses";
    };
    ipMeshPeerUnderlayV4s = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Underlay IPv4 addresses of mesh master peers";
    };
    ipMeshPeerUnderlayV6s = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Underlay IPv6 addresses of mesh master peers";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    services.bird = {
      enable = true;
      config = ''
        log syslog all;

        router id  ${cfg.ipUnderlayV4};

        define ASN = 65000;
        define ADDR_UNDERLAY_V4 = ${cfg.ipUnderlayV4};
        define ADDR_UNDERLAY_V6 = ${cfg.ipUnderlayV6};

        protocol device {
            # in newer versions of Linux we are notified about interface
            # status changes asynchronously so large value is okay, time in seconds
            scan time 60;
        }
        protocol direct {
            ipv4 { import all; };
            ipv6 { import all; };
        }

        protocol kernel kernel4 {
            ipv4 {
                export all;
                import none;
            };
        }
        protocol kernel kernel6 {
            ipv6 {
                export all;
                import none;
            };
        }

        template bgp rr_master_v4 {
            local ADDR_UNDERLAY_V4 as 65000;
            multihop;
            ipv4 {
                import all;
                export none;
            };
        }
        template bgp rr_master_v6 {
            local ADDR_UNDERLAY_V6 as 65000;
            multihop;
            ipv6 {
                import all;
                export none;
            };
        }

        ${
          let
            builder =
              ip:
              "protocol bgp rr_master_v4_${
                lib.replaceStrings [ "." ] [ "" ] ip
              } from rr_master_v4 { neighbor ${ip} as ASN; }";
          in
          lib.concatStringsSep "\n" (lib.map builder cfg.ipMeshPeerUnderlayV4s)
        }
        ${
          let
            builder =
              ip:
              "protocol bgp rr_master_v6_${
                lib.replaceStrings [ ":" ] [ "" ] ip
              } from rr_master_v6 { neighbor ${ip} as ASN; }";
          in
          lib.concatStringsSep "\n" (lib.map builder cfg.ipMeshPeerUnderlayV6s)
        }
      '';
    };
  };
}
