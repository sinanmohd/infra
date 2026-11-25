{
  config,
  lib,
  pkgs,
  inputsSinan,
  ...
}:
let
  cfg = config.sinan.k8s.kubeVip;
  k8sCfg = config.services.kubernetes;

  isMaster = lib.elem "master" k8sCfg.roles;
  mkDefaultPriority = (lib.mkDefault null).priority;
  kubelib = inputsSinan.nix-kube-generators.lib { inherit pkgs; };
  libSinan = inputsSinan.self.lib { inherit pkgs; };

  # NOTE: kube-vip talks to the apiserver on localhost and holds its virtual
  # address, so it may only run on masters, which get this label
  kubeVipControlPlaneLabel = "kube-vip.infra.sinanmohd.com/control-plane";

  # NOTE: the appVersion of the chart release below
  kubeVipImage = libSinan.ociImagePull {
    name = "ghcr.io/kube-vip/kube-vip";
    tag = "v1.2.4";
    digest = "sha256:dde4c0669d9058c74c69c0bc2f0122e26900e1e4b913c03577cb6e4e28083079";
    hashes = {
      amd64 = "sha256-THDoRl3Nc2qkDpQKMSGaS8SwxkJTffzAMl75YKV3qZg=";
      arm64 = "sha256-/YwpG36aQXK6kqZDVPO4yGafJ3HkEIyuonb92B+GE14=";
    };
  };
  cloudProviderImage = libSinan.ociImagePull {
    name = "ghcr.io/kube-vip/kube-vip-cloud-provider";
    tag = "v0.0.13";
    digest = "sha256:b8b6a5180e678b410e2c5dba86b87fa8099ada16e2f067d83f04e749f8ea54ab";
    hashes = {
      amd64 = "sha256-fEon2cv7b4AXnwrdiQBnskAVw2cn1Bppx76oIW8JlII=";
      arm64 = "sha256-kBF/s72/MJ/zCG5wHwWPY5q3BUbc4g/W+dEhF8HLToc=";
    };
  };
in
{
  options.sinan.k8s.kubeVip = {
    enable = lib.mkEnableOption ''
      kube-vip, for a highly available apiserver address and for
      LoadBalancer services, both announced over ARP'';

    address = lib.mkOption {
      type = lib.types.str;
      example = "192.168.1.100";
      description = ''
        Virtual IPv4 address of the apiserver. Workers reach the
        apiserver through it, masters use their own apiserver, so they
        come up before kube-vip runs.
      '';
    };

    interface = lib.mkOption {
      type = lib.types.str;
      example = "eth0";
      description = "Interface kube-vip announces the addresses on";
    };

    loadBalancerRange = lib.mkOption {
      type = lib.types.str;
      example = "192.168.1.200-192.168.1.250";
      description = ''
        IPv4 range kube-vip-cloud-provider gives LoadBalancer services
        their addresses from
      '';
    };

    values = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        env.vip_leaseduration = "10";
      };
      description = ''
        Helm values for the kube-vip chart, merged over the ones this module
        sets, key by key, so nested settings keep their siblings. Lists
        replace the module's list as a whole.
      '';
    };

    cloudProviderValues = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        cm.data.cidr-default = "192.168.2.0/24";
      };
      description = ''
        Helm values for the kube-vip-cloud-provider chart, merged like
        `values`
      '';
    };
  };

  config = lib.mkIf (config.sinan.k8s.enable && cfg.enable) {
    # NOTE: applied as cluster admin, both charts hold ClusterRoles the addon
    # manager may not grant
    services.kubernetes.addonManager.bootstrapAddons = lib.mkMerge [
      (libSinan.mkChartAddons {
        name = "kube-vip";
        namespace = "kube-system";
        chart = kubelib.downloadHelmChart {
          repo = "https://kube-vip.github.io/helm-charts";
          chart = "kube-vip";
          version = "0.11.2";
          chartHash = "sha256-ZGRBTyhoRAzCUMABF/EB5Zuxwf7FNwoNGp+cFOxwrb0=";
        };
        kubeVersion = "v${k8sCfg.package.version}";
        values = lib.recursiveUpdate {
          image = libSinan.ociImageValues kubeVipImage;
          config.address = cfg.address;
          env = {
            port = toString k8sCfg.apiserver.securePort;
            vip_interface = cfg.interface;
            vip_arp = "true";
            vip_subnet = "32";

            cp_enable = "true";
            vip_leaderelection = "true";
            # NOTE: 15, 10 and 2 seconds upstream, shorter so the virtual
            # address moves faster when its master goes down
            vip_leaseduration = "5";
            vip_renewdeadline = "3";
            vip_retryperiod = "1";
            # NOTE: on upstream, balances the address over every apiserver with
            # ipvs, a single holder is enough here
            lb_enable = "false";

            # NOTE: the kubernetes service ip needs kube-proxy or cilium, and
            # cilium needs the virtual address first, so talk to the apiserver
            # of this master directly
            KUBERNETES_SERVICE_HOST = "127.0.0.1";
            KUBERNETES_SERVICE_PORT = toString k8sCfg.apiserver.securePort;
          };
          nodeSelector.${kubeVipControlPlaneLabel} = "true";
          envValueFrom.vip_nodename.fieldRef.fieldPath = "spec.nodeName";
        } cfg.values;
      })
      (libSinan.mkChartAddons {
        name = "kube-vip-cloud-provider";
        namespace = "kube-system";
        chart = kubelib.downloadHelmChart {
          repo = "https://kube-vip.github.io/helm-charts";
          chart = "kube-vip-cloud-provider";
          version = "0.2.11";
          chartHash = "sha256-QY9CyP4Tl6twwCp8O1rilak28SG+EEnGTRyrdhF19cU=";
        };
        kubeVersion = "v${k8sCfg.package.version}";
        values = lib.recursiveUpdate {
          image = libSinan.ociImageValues cloudProviderImage;
          cm.data.range-global = cfg.loadBalancerRange;
        } cfg.cloudProviderValues;
      })
    ];

    services.kubernetes = {
      apiserverAddress = lib.mkOverride (mkDefaultPriority - 200) (
        if isMaster then
          "https://127.0.0.1:${toString k8sCfg.apiserver.securePort}"
        else
          "https://${cfg.address}:${toString k8sCfg.apiserver.securePort}"
      );
      apiserver.extraSANs = lib.mkIf isMaster [ cfg.address ];

      kubelet = lib.mkIf k8sCfg.kubelet.enable {
        seedDockerImages = [
          kubeVipImage
          cloudProviderImage
        ];
        extraOpts = lib.mkIf isMaster "--node-labels=${kubeVipControlPlaneLabel}=true";
      };

    };
  };
}
