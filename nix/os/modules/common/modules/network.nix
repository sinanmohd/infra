{
  systemd.network.enable = true;
  networking.useDHCP = false;

  programs.mosh.enable = true;
  services = {
    resolved = {
      enable = true;
      settings.Resolve = {
        DNSOverTLS = "opportunistic";
        DNSSEC = "allow-downgrade";
      };
    };
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };
  };
}
