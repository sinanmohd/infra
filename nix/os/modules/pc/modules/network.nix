{
  networking.wireless.iwd.enable = true;

  systemd.network = {
    enable = true;
    networks = {
      "99-wireless-dhcp" = {
        matchConfig.Type = "wlan";
        networkConfig.DHCP = "yes";
        dhcpV4Config = {
          UseHostname = "no";
          UseDNS = "no";
        };
        dhcpV6Config.UseDNS = "no";
      };
      "99-wired-dhcp" = {
        matchConfig = {
          Kind = "!*";
          Type = "ether";
        };
        networkConfig.DHCP = "yes";
        dhcpV4Config = {
          UseHostname = "no";
          UseDNS = "no";
        };
        dhcpV6Config.UseDNS = "no";
      };
    };
  };
}
