{
  config,
  lib,
  ...
}:

let
  domain = config.global.userdata.domain;
  storage = "/hdd/users/sftp/shr";
in
{
  security.acme.certs.${domain}.postRun = "systemctl reload nginx.service";
  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
    allowedUDPPorts = [ 443 ];
  };

  services.prometheus.exporters = {
    nginxlog = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
    nginx = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
  };

  services.nginx = {
    enable = true;
    statusPage = true;
    enableQuicBPF = true;

    recommendedTlsSettings = true;
    # breaks home-assistant proxy for some reason
    # only the first request goes through, then site hangs
    # recommendedZstdSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedBrotliSettings = true;
    eventsConfig = "worker_connections 1024;";
    appendHttpConfig = ''
      quic_retry on;
      quic_gso on;
      add_header Alt-Svc 'h3=":443"; ma=2592000; persist=1';
    '';

    virtualHosts =
      let
        defaultOpts = {
          # reuseport = true;
          quic = true;
          http3 = true;
          forceSSL = true;
          useACMEHost = domain;
        };
      in
      {
        "${domain}" = defaultOpts // {
          default = true;
          globalRedirect = "www.${domain}";

          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            client_max_body_size 0;
          '';

          locations = {
            "/.well-known/matrix/server".return = ''
              200 '{ "m.server": "${domain}:443" }'
            '';

            "/.well-known/matrix/client".return = ''
              200 '${
                builtins.toJSON {
                  "m.homeserver".base_url = "https://${domain}";
                  "org.matrix.msc3575.proxy".url = "https://sliding.${domain}";
                  "m.identity_server".base_url = "https://vector.im";
                }
              }'
            '';

            "/.well-known/".proxyPass = "http://127.0.0.1:8085";

            "~ ^(\\/_matrix|\\/_synapse\\/client)".proxyPass =
              "http://127.0.0.1:${toString config.services.dendrite.httpPort}";
          };
        };

        "sliding.${domain}" = defaultOpts // {
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            client_max_body_size 0;
          '';

          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://${config.services.matrix-sliding-sync-dirty.settings.SYNCV3_BINDADDR}";
          };
        };

        "headscale.${domain}" = defaultOpts // {
          locations = {
            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://localhost:${toString config.services.headscale.port}";
            };
            "= /".return = "307 https://headscale.${domain}/admin";
            "/admin".proxyPass = "http://localhost:${toString config.services.headplane.settings.server.port}";
          };
        };

        "${config.services.grafana.settings.server.domain}" = defaultOpts // {
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            client_max_body_size 0;
          '';

          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://${config.services.grafana.settings.server.http_addr}:${builtins.toString config.services.grafana.settings.server.http_port}";
          };
        };

        "www.${domain}" = defaultOpts // {
          extraConfig = ''
            ssl_early_data on;
          '';

          root = "/var/www/${domain}";
        };

        "bin.${domain}" = defaultOpts // {
          extraConfig = ''
            ssl_early_data on;
          '';
          root = "${storage}/bin";
          locations."= /".return = "307 https://www.${domain}";
        };

        "static.${domain}" = defaultOpts // {
          extraConfig = ''
            ssl_early_data on;
          '';
          root = "${storage}/static";
          locations."= /".return = "301 https://www.${domain}";
        };

        "home.${domain}" = defaultOpts // {
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.home-assistant.config.http.server_port}";
          };
        };

        "stalwart.${domain}" = defaultOpts // {
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:8085";
          };
        };

        "vaultwarden.${domain}" = defaultOpts // {
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
          };
        };

        "s3.${domain}" = defaultOpts // {
          extraConfig = ''
            # Allow special characters in headers
            ignore_invalid_headers off;
            # Allow any size file to be uploaded.
            # Set to a value such as 1000m; to restrict file size to a specific value
            client_max_body_size 0;
            # Disable buffering
            proxy_buffering off;
            proxy_request_buffering off;
          '';
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:9000";
            extraConfig = ''
              proxy_connect_timeout 300;
              chunked_transfer_encoding off;
            '';
          };
        };

        "minio.${domain}" = defaultOpts // {
          extraConfig = ''
            # Allow special characters in headers
            ignore_invalid_headers off;
            # Allow any size file to be uploaded.
            # Set to a value such as 1000m; to restrict file size to a specific value
            client_max_body_size 0;
            # Disable buffering
            proxy_buffering off;
            proxy_request_buffering off;
          '';
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:9003";
            extraConfig = ''
              # This is necessary to pass the correct IP to be hashed
              real_ip_header X-Real-IP;
              proxy_connect_timeout 300;
              chunked_transfer_encoding off;
            '';
          };
        };

        "mta-sts.${domain}" = defaultOpts // {
          extraConfig = ''
            ssl_early_data on;
          '';
          locations."= /.well-known/mta-sts.txt".return = ''200 "${
            lib.strings.concatStringsSep "\\n" [
              "version: STSv1"
              "mode: enforce"
              "mx: mail.${domain}"
              "max_age: 86400"
            ]
          }"'';
        };

        "immich.${domain}" = defaultOpts // {
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://${config.services.immich.host}:${builtins.toString config.services.immich.port}";
          };

          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            client_max_body_size 0;
          '';
        };

        "nixbin.${domain}" = defaultOpts // {
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            client_max_body_size 0;
          '';

          locations = {
            "= /files".return = "301 https://nixbin.${domain}/files/";
            "/files/" = {
              alias = "/nix/store/";
              extraConfig = "autoindex on;";
            };

            "= /" = {
              extraConfig = ''
                add_header Content-Type text/html;
                add_header Alt-Svc 'h3=":443"; ma=2592000; persist=1';
              '';
              return = ''
                200
                              '<!DOCTYPE html>
                              <html lang="en">
                                <head>
                                  <meta charset="UTF-8">
                                  <title>Nix Cache</title>
                                </head>
                                <body>
                                  <center>
                                    <h1 style="font-size: 8em">
                                      ❄️ Nix Cache
                                    </h1>
                                    <p style="font-weight: bold">
                                      Public Key: nixbin.sinanmohd.com:dXV3KDPVrm+cGJ2M1ZmTeQJqFGaEapqiVoWHgYDh03k=
                                    </p>
                                  </center>
                                </body>
                              </html>'
              '';
            };

            "/".proxyPass =
              "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
          };
        };

        "www.alinafs.com" = defaultOpts // {
          useACMEHost = null;
          enableACME = true;
          globalRedirect = "alinafs.com/home";
          extraConfig = ''
            ssl_early_data on;
          '';
        };
        "alinafs.com" = defaultOpts // {
          useACMEHost = null;
          enableACME = true;

          locations = {
            "/metrics".return = "307 /home/";
            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:${builtins.toString config.services.alina.port}";
            };
          };

          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            client_max_body_size 0;
          '';
        };
      };
  };
}
