{ ... }:

{
  services.iperf3 = {
    enable = true;

    bind = "192.168.43.1";
    openFirewall = true;
  };
}
