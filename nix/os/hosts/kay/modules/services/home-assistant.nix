{ pkgs, ... }:
{
  services.postgresql = {
    enable = true;

    ensureDatabases = [ "hass" ];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
      }
    ];
  };

  services.home-assistant = {
    enable = true;
    package =
      (pkgs.home-assistant.override {
        extraPackages = py: with py; [ psycopg2 ];
      }).overrideAttrs
        (oldAttrs: {
          doInstallCheck = false;
        });

    extraComponents = [
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"
      "tplink"
      "tuya"
      "utility_meter"
    ];

    config = {
      default_config = { };

      recorder.db_url = "postgresql://@/hass";
      http = {
        server_host = "127.0.0.1";
        trusted_proxies = [ "127.0.0.1" ];
        use_x_forwarded_for = true;
      };
    };
  };
}
