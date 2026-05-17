{ pkgs, ... }:
let
  lanHost = "192.168.43.1,fe80::caa3:62ff:fe90:cc13";
in
{
  systemd.services.k3s.path = [ pkgs.criu ];

  environment = {
    variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    systemPackages = with pkgs; [
      kubernetes-helm
      k9s
    ];
  };

  services.k3s = {
    enable = true;
    gracefulNodeShutdown.enable = true;
    clusterInit = true;
    role = "server";
    nodeIP = lanHost;
    extraFlags = [
      "--write-kubeconfig-group users"
      "--write-kubeconfig-mode 0640"
      "--cluster-cidr=10.42.0.0/16,fd12:b0d8:b00b::/56"
      "--service-cidr=10.43.0.0/16,fd12:b0d8:babe::/112"
      "--flannel-ipv6-masq"
    ];
    manifests.traefik-daemonset = {
      enable = true;
      source = ./traefik-daemonset.yaml;
      target = "traefik-daemonset.yaml";
    };
  };
}
