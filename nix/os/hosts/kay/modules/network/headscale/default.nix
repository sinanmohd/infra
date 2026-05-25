{
  config,
  pkgs,
  lib,
  ...
}:
let
  url = "https://headscale.${config.global.userdata.domain}";
  stunPort = 3478;

  # A workaround generate a valid Headscale config accepted by Headplane when `config_strict == true`.
  settings = lib.recursiveUpdate config.services.headscale.settings {
    tls_cert_path = "/dev/null";
    tls_key_path = "/dev/null";
    policy.path = "/dev/null";
  };
  format = pkgs.formats.yaml { };
  headscaleConfig = format.generate "headscale.yml" settings;

  policyFormat = pkgs.formats.json { };
  policy = {
    groups = {
      "group:owner" = [ "sinan@" ];
    };

    tagOwners = {
      "tag:internal" = [ "group:owner" ];
      "tag:gaijin" = [ "group:owner" ];
      "tag:headplane" = [ "group:owner" ];

      "tag:bud_staff" = [ "group:owner" ];
      "tag:bud_internal" = [ "group:owner" ];
      "tag:bud_clients" = [ "group:owner" ];
    };

    autoApprovers = {
      routes = {
        "192.168.43.0/24" = [
          "tag:internal"
        ];
        "192.168.38.0/24" = [
          "tag:internal"
        ];
      };
      exitNode = [
        "tag:internal"
      ];
    };

    acls = [
      {
        action = "accept";
        src = [ "group:owner" ];
        dst = [ "*:*" ];
      }

      {
        action = "accept";
        src = [ "tag:headplane" ];
        dst = [ "*:*" ];
      }

      {
        action = "accept";
        src = [ "nazer@" ];
        dst = [ "autogroup:internet:*" ];
      }

      {
        action = "accept";
        src = [ "tag:bud_staff" ];
        dst = [ "tag:bud_internal:*" ];
      }

      {
        action = "accept";
        src = [ "tag:bud_staff" ];
        dst = [ "tag:bud_clients:*" ];
      }
    ];
  };
in
{
  environment.systemPackages = [ config.services.headscale.package ];

  sops.secrets = {
    # server
    "headplane/cookie_secret" = {
      owner = config.services.headscale.user;
      sopsFile = ./secrets.yaml;
    };
    "headplane/preauth_key" = {
      owner = config.services.headscale.user;
      sopsFile = ./secrets.yaml;
    };
    "headscale/noise_private_key" = {
      owner = config.services.headscale.user;
      sopsFile = ./secrets.yaml;
    };
    "headscale/derp_private_key" = {
      owner = config.services.headscale.user;
      sopsFile = ./secrets.yaml;
    };
    # client
    "tailscale/preauth_key".sopsFile = ./secrets.yaml;
  };

  networking.firewall = {
    interfaces.ppp0.allowedUDPPorts = [ stunPort ];
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
  };
  # for exit node only
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  services = {
    headscale = {
      enable = true;
      port = 8139;

      settings = {
        logtail.enabled = false;
        server_url = url;
        noise.private_key_path = config.sops.secrets."headscale/noise_private_key".path;
        dns = {
          base_domain = "tsnet.${config.global.userdata.domain}";
          override_local_dns = false;
        };
        derp = {
          server = {
            enabled = true;
            private_key_path = config.sops.secrets."headscale/derp_private_key".path;
            region_code = config.networking.hostName;
            region_name = config.networking.hostName;
            stun_listen_addr = "0.0.0.0:${toString stunPort}";
            region_id = 6969;
            automatically_add_embedded_derp_region = true;
          };
          urls = [ ];
        };
        policy = {
          mode = "file";
          path = policyFormat.generate "acl.json" policy;
        };
      };
    };

    headplane = {
      enable = true;
      settings = {
        server = {
          port = 8140;
          cookie_secret_path = config.sops.secrets."headplane/cookie_secret".path;
        };
        headscale = {
          inherit url;
          config_path = "${headscaleConfig}";
        };
        integration.agent = {
          enabled = true;
          host_name = "headplane";
          pre_authkey_path = config.sops.secrets."headplane/preauth_key".path;
        };
      };
    };

    tailscale = {
      enable = true;
      openFirewall = true;

      authKeyFile = config.sops.secrets."tailscale/preauth_key".path;
      extraUpFlags = [
        "--login-server=${url}"
        "--advertise-exit-node"
        "--advertise-routes=192.168.43.0/24,192.168.38.0/24"
        "--advertise-tags=tag:internal"
      ];
    };
  };
}
