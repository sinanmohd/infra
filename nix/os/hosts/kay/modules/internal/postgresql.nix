{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.postgresql = {
    enable = true;
    package = with pkgs; postgresql_15;
    authentication = lib.mkForce ''
      #type database DBuser  origin-address auth-method
      # unix socket
      local all      all                    trust
      # ipv4
      host  all      all     127.0.0.1/32   trust
      # ipv6
      host  all      all     ::1/128        trust
    '';

    settings.log_timezone = config.time.timeZone;
  };

  services.prometheus.exporters.postgres = {
    enable = true;
    listenAddress = "127.0.0.1";
  };
}
