{
  config,
  lib,
  pkgs,
  inputsSinan,
  ...
}:
let
  cfg = config.sinan.k8s.cilium;
  k8sCfg = config.services.kubernetes;
  kubeVipCfg = config.sinan.k8s.kubeVip;

  kubelib = inputsSinan.nix-kube-generators.lib { inherit pkgs; };
  libSinan = inputsSinan.self.lib { inherit pkgs; };

  # NOTE: the image tags and digests below are the ones this chart release
  # pins, bump them together
  # TODO: make bumping this and kube-vip easier, maybe with a script that
  # reads the pins from a file instead of this module
  chart = kubelib.downloadHelmChart {
    repo = "https://helm.cilium.io";
    chart = "cilium";
    version = "1.20.5";
    chartHash = "sha256-K3fcFNlHi1Jw5nljFv6vvnJ1rgmdLXTV1ubMmPR/Cpw=";
  };
  images = {
    cilium = libSinan.ociImagePull {
      name = "quay.io/cilium/cilium";
      tag = "v1.20.5";
      digest = "sha256:aa72499f075ad729947ea91b026218aceba24f1a8e4534bf36b8368c7c561526";
      hashes = {
        amd64 = "sha256-A6Aa21CXZW3FJVXcwoTo7+Sz6onXRN0ZVdP9koI5Y7M=";
        arm64 = "sha256-Ai4o3dw1ckru+ck6xWx+zIfbXUn/xxhl+8moNVh74ZM=";
      };
    };
    operator = libSinan.ociImagePull {
      name = "quay.io/cilium/operator-generic";
      tag = "v1.20.5";
      digest = "sha256:c6e7de6665aa9701db86c4fe46828a75a0d167afe084a9ffb5bce34b2c4fa8c4";
      hashes = {
        amd64 = "sha256-HAZ45JFJyrkY4oZmKFoemjZ/RSHAKxQiBii3cfHJdK0=";
        arm64 = "sha256-JwgiT1LAC6uzwZucsSEdJOHnXlD1rmQMmgkM1MgPBQA=";
      };
    };
    hubbleRelay = libSinan.ociImagePull {
      name = "quay.io/cilium/hubble-relay";
      tag = "v1.20.5";
      digest = "sha256:d0b3f5b944adc4a79f82ac51bcdc2d723b734c2c97872d8551626ad48b3c5538";
      hashes = {
        amd64 = "sha256-uQ0IfiPXllAsYstNd52cw/yoS2YENFrdfWM/sqwjzyk=";
        arm64 = "sha256-MRGLPCiqPohDv0kQmb82kgwrQBrdQk0DOvB940/zCoU=";
      };
    };
    hubbleUi = libSinan.ociImagePull {
      name = "quay.io/cilium/hubble-ui";
      tag = "v0.13.6";
      digest = "sha256:049a80a03585c043d0c3121bdc518c72b0fd42bae07e4bcce0fdb8f1e88041d0";
      hashes = {
        amd64 = "sha256-Q+YA34Kj/eJoA8I+Xm0ng7jgo6mEWsPP/54dZw1kJnU=";
        arm64 = "sha256-kG2cW6hcdu8h+4B5YpT+twy4XFrtsT8AXpWop/Tn8UU=";
      };
    };
    hubbleUiBackend = libSinan.ociImagePull {
      name = "quay.io/cilium/hubble-ui-backend";
      tag = "v0.13.6";
      digest = "sha256:83b3fc763f3d49948c306bf49b08277383e195904b9ca5c0c0022b2112628787";
      hashes = {
        amd64 = "sha256-uStaFRhhxie+j7vhKA+meSWiX/p7FPMe5IxDfVMZmVU=";
        arm64 = "sha256-mnc05B00kn7rJI4sO0vCMzguAdRfozMTd0Qx44evDgc=";
      };
    };
    certgen = libSinan.ociImagePull {
      name = "quay.io/cilium/certgen";
      tag = "v0.4.14";
      digest = "sha256:2f89929b7474b739d5225d69f44bd70d9e28067ff6dc7fdbe0f6407828fb8395";
      hashes = {
        amd64 = "sha256-NyPOTIeVQW8OlALF+TvWbr0kUbUvh5sLc/9vreiAapg=";
        arm64 = "sha256-hiQyuzLj0L3NTymcD8wuW5PqE+L+h9BoKotoK+OBBac=";
      };
    };
    envoy = libSinan.ociImagePull {
      name = "quay.io/cilium/cilium-envoy";
      tag = "v1.39.6-1794557904-dee711ff0e84b106edd0abcdd71961af1b870359";
      digest = "sha256:bdef13043ebaa7b9dcd8e3a86be41080bb5369e017cd759a12daf89e2b8fafe7";
      hashes = {
        amd64 = "sha256-nySTpzQPliTtN7uHyfuD9sQl6eAofyZNiJz6YNfrRao=";
        arm64 = "sha256-n9pwzNlc8eBGIIfm3zrgjqyOZSfWhzQA6RxIOe6PX9g=";
      };
    };
  };

  # NOTE: the kubelet empties /opt/cni/bin on every start and only links its cni
  # packages back, so cilium-cni comes from the agent image as a package instead
  # of being copied there by the agent
  ciliumCni = pkgs.runCommand "cilium-cni-${images.cilium.imageTag}" { } ''
    tar --extract --file ${images.cilium}
    for layer in $(find . -name '*.tar'); do
      tar --extract --file "$layer" opt/cni/bin/cilium-cni 2> /dev/null || true
    done
    install -D --mode 555 opt/cni/bin/cilium-cni "$out/bin/cilium-cni"
  '';

  # NOTE: the chart refers to images by digest unless told not to, seeded images
  # lose the digest of the registry
  imageValues = image: libSinan.ociImageValues image // { useDigest = false; };

  values = {
    kubeProxyReplacement = true;
    ipam.mode = "kubernetes";
    rollOutCiliumPods = true;
    image = imageValues images.cilium;

    # NOTE: without kube-proxy the kubernetes service ip only works once the
    # agent runs, so it needs the apiserver directly
    # NOTE: not networking.hostName, every master applies this chart and would
    # point the whole cluster at itself, so the masters keep overwriting each
    # other and rolling the agents. The first etcd member is the same on every
    # master
    k8sServiceHost =
      if kubeVipCfg.enable then kubeVipCfg.address else lib.head config.sinan.k8s.etcdMembers;
    k8sServicePort = toString k8sCfg.apiserver.securePort;

    # NOTE: the cni config and binary come from the kubelet, see ciliumCni var
    cni = {
      install = false;
      customConf = true;
    };

    operator.image = imageValues images.operator // {
      repository = "quay.io/cilium/operator";
      suffix = "";
    };

    # TODO: istio
    envoy.image = imageValues images.envoy;

    certgen.image = imageValues images.certgen;
    hubble = {
      relay = {
        enabled = true;
        image = imageValues images.hubbleRelay;
      };
      ui = {
        enabled = true;
        frontend.image = imageValues images.hubbleUi;
        backend.image = imageValues images.hubbleUiBackend;
      };
      # NOTE: the helm method would render the private keys into /nix/store
      tls.auto.method = "cronJob";
    };
  }
  // lib.optionalAttrs kubeVipCfg.enable {
    # NOTE: kube-vip-cloud-provider hands out the LoadBalancer addresses
    defaultLBServiceIPAM = "none";
  }
  // lib.optionalAttrs config.sinan.k8s.ipv6.enable {
    ipv6.enabled = true;
  };
in
{
  options.sinan.k8s.cilium = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to run Cilium from its upstream chart as the CNI and kube-proxy
        replacement, with Hubble, in place of flannel and kube-proxy.

        Without kube-proxy the agents reach the apiserver directly: through
        `sinan.k8s.kubeVip.address` when kube-vip is enabled, which stays
        up when a master goes down, otherwise through the first of
        `sinan.k8s.etcdMembers` alone, which is not highly available.
      '';
    };
    values = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        operator.replicas = 1;
      };
      description = ''
        Helm values for the Cilium chart, merged over the ones this module
        sets, key by key, so nested settings keep their siblings. Lists
        replace the module's list as a whole.
      '';
    };
  };

  config = lib.mkIf (config.sinan.k8s.enable && cfg.enable) {
    services.kubernetes = {
      # NOTE: applied as cluster admin, the chart holds ClusterRoles the addon
      # manager may not grant
      addonManager.bootstrapAddons = libSinan.mkChartAddons {
        name = "cilium";
        namespace = "kube-system";
        inherit chart;
        kubeVersion = "v${k8sCfg.package.version}";
        values = lib.recursiveUpdate values cfg.values;
      };

      flannel.enable = false;
      proxy.enable = false;
      # NOTE: the agent and its init containers are privileged
      # TODO: restrict this to cillium only
      apiserver.allowPrivileged = true;

      kubelet = lib.mkIf k8sCfg.kubelet.enable {
        seedDockerImages = lib.attrValues images;
        cni = {
          packages = [ ciliumCni ];
          config = [
            {
              cniVersion = "0.3.1";
              name = "cilium";
              type = "cilium-cni";
              enable-debug = false;
            }
          ];
        };
      };
    };

    # NOTE: the kubelet preStart imports every seeded image again on each start,
    # the cilium images take minutes, past the default 90s, and every retry
    # starts the import over
    # TODO: UPSTREAM: only seed images if it's not already seeded
    systemd.services.kubelet.serviceConfig.TimeoutStartSec = lib.mkIf k8sCfg.kubelet.enable (
      lib.mkDefault "10min"
    );

    # NOTE: no rule for the NodePort range, cilium handles NodePorts in ebpf on
    # the device before the INPUT chain the firewall filters
    networking.firewall = lib.mkIf (config.sinan.k8s.openFirewall && k8sCfg.kubelet.enable) {
      # NOTE: health checks between agents and hubble relay reaching the agents
      allowedTCPPorts = [
        4240
        4244
      ];
      # NOTE: vxlan between nodes
      allowedUDPPorts = [ 8472 ];
    };
  };
}
