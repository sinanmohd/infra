{ config, lib, ... }:
let
  cfg = config.sinan.bgp.mesh;

  anycastIpv4 = "10.100.100.10";
  anycastIpv4CIDR = "10.100.0.0/16";
  anycastIpv6 = "fd00:100::10";
  anycastIpv6CIDR = "fd00:100::/48";
in
{
  options.sinan.bgp.mesh = {
    enable = lib.mkEnableOption "bgp mesh";
    ipUnderlayV4 = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Underlay IPv4 addresses";
    };
    CIDRUnderlayV4 = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Underlay IPv4 addresses";
    };
    ipUnderlayV6 = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Underlay IPv6 addresses";
    };
    CIDRUnderlayV6 = lib.mkOption {
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
        define ADDR_UNDERLAY_V4_CIDR = ${cfg.CIDRUnderlayV4};
        define ADDR_UNDERLAY_V6 = ${cfg.ipUnderlayV6};
        define ADDR_UNDERLAY_V6_CIDR = ${cfg.CIDRUnderlayV6};
        define CLUSTER_ID = ${anycastIpv4};
        define ADDR_OVERLAY_RR_ANYCAST_V4 = ${anycastIpv4};
        define ADDR_OVERLAY_RR_ANYCAST_V4_MAX = ${anycastIpv4}/32;
        define ADDR_OVERLAY_RR_ANYCAST_V4_CIDR = ${anycastIpv4CIDR};
        define ADDR_OVERLAY_RR_ANYCAST_V6 = ${anycastIpv6};
        define ADDR_OVERLAY_RR_ANYCAST_V6_MAX = ${anycastIpv6}/128;
        define ADDR_OVERLAY_RR_ANYCAST_V6_CIDR = ${anycastIpv6CIDR};

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

        filter bgp_export_v4 {
            if net = ADDR_OVERLAY_RR_ANYCAST_V4_MAX then accept;
            if source = RTS_BGP then accept;
            reject;
        }
        filter bgp_export_v6 {
            if net = ADDR_OVERLAY_RR_ANYCAST_V6_MAX then accept;
            if source = RTS_BGP then accept;
            reject;
        }

        template bgp mesh_master_v4 {
            local ADDR_UNDERLAY_V4 as ASN;
            multihop;
            ipv4 {
                import all;
                export filter bgp_export_v4;
            };
        }
        template bgp mesh_master_v6 {
            local ADDR_UNDERLAY_V6 as ASN;
            multihop;
            ipv6 {
                import all;
                export filter bgp_export_v6;
            };
        }
        ${
          let
            builder =
              ip:
              "protocol bgp mesh_master_v6_${
                lib.replaceStrings [ "." ] [ "" ] ip
              } from mesh_master_v4 { neighbor ${ip} as ASN; }";
          in
          lib.concatStringsSep "\n" (lib.map builder cfg.ipMeshPeerUnderlayV4s)
        }
        ${
          let
            builder =
              ip:
              "protocol bgp mesh_master_v6_${
                lib.replaceStrings [ ":" ] [ "" ] ip
              } from mesh_master_v6 { neighbor ${ip} as ASN; }";
          in
          lib.concatStringsSep "\n" (lib.map builder cfg.ipMeshPeerUnderlayV6s)
        }

        template bgp rr_client_v4 {
            rr client;
            rr cluster id CLUSTER_ID;
            multihop;
            ipv4 {
                import all;
                export filter bgp_export_v4;
            };
        }
        template bgp rr_client_v6 {
            rr client;
            rr cluster id CLUSTER_ID;
            multihop;
            ipv6 {
                import all;
                export filter bgp_export_v6;
            };
        }
        protocol bgp rr_client_underlay_v4 from rr_client_v4 {
            dynamic name "rr_client_underlay_v4_";
            local ADDR_UNDERLAY_V4 as ASN;
            neighbor range ADDR_UNDERLAY_V4_CIDR as ASN;
        }
        protocol bgp rr_client_underlay_v6 from rr_client_v6 {
            dynamic name "rr_client_underlay_v6_";
            local ADDR_UNDERLAY_V6 as ASN;
            neighbor range ADDR_UNDERLAY_V6_CIDR as ASN;
        }
        protocol bgp rr_client_anycast_v4 from rr_client_v4 {
            dynamic name "rr_client_anycast_v4_";
            local ADDR_OVERLAY_RR_ANYCAST_V4 as ASN;
            neighbor range ADDR_OVERLAY_RR_ANYCAST_V4_CIDR as ASN;
        }
        protocol bgp rr_client_anycast_v6 from rr_client_v6 {
            dynamic name "rr_client_anycast_v6_";
            local ADDR_OVERLAY_RR_ANYCAST_V6 as ASN;
            neighbor range ADDR_OVERLAY_RR_ANYCAST_V6_CIDR as ASN;
        }
      '';
    };

    boot.kernelModules = [ "dummy" ];
    systemd.network.netdevs = {
      "20-bgp-rr-anycast" = {
        netdevConfig = {
          Name = "bgp-rr-anycast";
          Kind = "dummy";
        };
      };
    };
    systemd.network.networks = {
      "30-bgp-rr-anycast" = {
        matchConfig.Name = "bgp-rr-anycast";
        address = [
          "${anycastIpv4}/32"
          "${anycastIpv6}/128"
        ];
      };
    };
  };
}
