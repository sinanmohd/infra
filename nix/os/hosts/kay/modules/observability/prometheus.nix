{ config, ... }:
{
  services.prometheus = {
    enable = true;
    port = 9001;

    scrapeConfigs = [
      {
        job_name = "kay";
        scrape_interval = "1s";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
          }
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.dnsmasq.port}" ];
          }
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ];
          }
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginxlog.port}" ];
          }
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.postgres.port}" ];
          }
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.snmp.port}" ];
          }
          {
            targets = [ "127.0.0.1:${toString config.services.dendrite.httpPort}" ];
          }
        ];
      }
    ];

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };
    };
  };
}
