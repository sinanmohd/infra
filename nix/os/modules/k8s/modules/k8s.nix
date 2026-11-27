{
  config,
  options,
  lib,
  pkgs,
  inputsSinan,
  ...
}:
let
  cfg = config.sinan.k8s;
  k8sCfg = config.services.kubernetes;
  libSinan = inputsSinan.self.lib { inherit pkgs; };

  k8sCa = config.sinan.certToolkit.cas.kubernetes;
  etcdCa = config.sinan.certToolkit.cas.etcd;
  frontProxyCa = config.sinan.certToolkit.cas.frontProxy;

  isMaster = lib.elem "master" k8sCfg.roles;
  kubectl = lib.getExe' k8sCfg.package "kubectl";
  mkDefaultPriority = (lib.mkDefault null).priority;

  hostAddresses =
    let
      /**
        The static ipv4 and ipv6 addresses of an interface, without their
        prefix lengths.

        # Inputs

        `interface`

        : Evaluated `networking.interfaces.<name>`

        # Type

        ```
        interfaceAddresses :: AttrSet -> [String]
        ```
      */
      interfaceAddresses =
        interface: lib.catAttrs "address" (interface.ipv4.addresses ++ interface.ipv6.addresses);
    in
    lib.concatMap interfaceAddresses (lib.attrValues config.networking.interfaces);

  /**
    Compute the first IP in a CIDR range, used for the default kubernetes
    apiserver service IP (e.g. 10.0.0.1 for 10.0.0.0/24). An IPv6 range has
    to end its network address in `::`, which is how they are written.

    # Inputs

    `cidr`

    : An IPv4 or IPv6 CIDR string (e.g. "10.0.0.0/24" or "fd10:2::/112")

    # Type

    ```
    firstServiceIp :: String -> String
    ```

    # Examples
    :::{.example}
    ## `firstServiceIp` usage example

    ```nix
    firstServiceIp "10.0.0.0/24"
    => "10.0.0.1"
    firstServiceIp "fd10:2::/112"
    => "fd10:2::1"
    ```

    :::
  */
  firstServiceIp =
    cidr:
    let
      network = lib.head (lib.splitString "/" cidr);
    in
    if lib.hasInfix ":" cidr then
      if lib.hasSuffix "::" network then
        "${network}1"
      else
        throw "sinan.k8s: the IPv6 range ${cidr} must end its network address in ::"
    else
      lib.concatStringsSep "." (lib.take 3 (lib.splitString "." network)) + ".1";

  /**
    The files a client needs to talk to the apiserver with a leaf of the
    kubernetes CA, in the shape of the upstream `kubeconfig` options.

    # Inputs

    `leaf`

    : Evaluated `sinan.certToolkit.cas.kubernetes.leaves.<name>`

    # Type

    ```
    clientCert :: AttrSet -> { caFile :: String; certFile :: String; keyFile :: String; }
    ```
  */
  clientCert = leaf: {
    caFile = k8sCa.root.certPath;
    certFile = leaf.certPath;
    keyFile = leaf.keyPath;
  };

  /**
    Write a kubeconfig for the apiserver of this cluster to the store.

    # Inputs

    `name`

    : Name of the kubeconfig, used for its file and user name

    `leaf`

    : Evaluated `sinan.certToolkit.cas.kubernetes.leaves.<name>` to log in with

    # Type

    ```
    mkKubeconfig :: String -> AttrSet -> Derivation
    ```
  */
  mkKubeconfig =
    name: leaf:
    k8sCfg.lib.mkKubeConfig name (
      clientCert leaf
      // {
        server = k8sCfg.apiserverAddress;
      }
    );

  adminKubeconfig = mkKubeconfig "cluster-admin" k8sCa.leaves.admin;
in
{
  options.sinan.k8s = {
    enable = lib.mkEnableOption "Kubernetes with root and leaf certs from the cert toolkit";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the firewall ports of the Kubernetes services and
        etcd this host runs, based on its `services.kubernetes.roles`
      '';
    };

    ipv4 = {
      podCidr = lib.mkOption {
        type = lib.types.str;
        default = "10.42.0.0/16";
        description = ''
          IPv4 range of the pods.
        '';
      };

      serviceCidr = lib.mkOption {
        type = lib.types.str;
        default = "10.43.0.0/16";
        description = ''
          IPv4 range of the Service cluster IPs
        '';
      };
    };

    ipv6 = {
      enable = lib.mkEnableOption ''
        dual-stack, IPv4 first, so pods and Services get an IPv6 address too.
        Needs Cilium, and every node an IPv6 address, set both in
        `services.kubernetes.kubelet.nodeIp` as `<ipv4>,<ipv6>`'';

      podCidr = lib.mkOption {
        type = lib.types.str;
        default = "fd12:b0d8:b00b::/56";
        description = ''
          IPv6 range of the pods, each node gets a /64 of it. ULA by
          default, pods reach the outside through masquerade on the node.
        '';
      };

      serviceCidr = lib.mkOption {
        type = lib.types.str;
        default = "fd12:b0d8:babe::/112";
        description = ''
          IPv6 range of the Service cluster IPs, its network address has to
          end in `::`
        '';
      };
    };

    etcdMembers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.networking.hostName ];
      defaultText = lib.literalExpression "[ config.networking.hostName ]";
      example = [
        "master1"
        "master2"
        "master3"
      ];
      description = ''
        Host names of the masters forming the etcd cluster, each reachable
        by its name and running etcd under it. Sets every member's name,
        advertised URLs and initial cluster, and the etcd servers of the
        apiserver. The default is a single member on this master.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.ipv6.enable -> cfg.cilium.enable;
        message = "sinan.k8s.ipv6 needs sinan.k8s.cilium, flannel and kube-proxy are IPv4 only here";
      }
      {
        assertion = !options.services.kubernetes.masterAddress.isDefined;
        message = ''
          services.kubernetes.masterAddress is not used by sinan.k8s, set
          sinan.k8s.etcdMembers on masters and services.kubernetes.apiserverAddress
          on workers, or enable sinan.k8s.kubeVip
        '';
      }
    ];

    sinan.certToolkit = {
      dir = lib.mkDefault "nix/os/modules/k8s/certs";
      defaults.key = lib.mkDefault {
        algo = "ecdsa";
        size = 256;
      };
      rootDefaults.expiry = lib.mkDefault "876000h";
      leafDefaults = {
        expiry = lib.mkDefault "87600h";
        usages = lib.mkDefault [
          # NOTE: lets the key sign the tls handshake, needed by ecdsa and rsa
          # keys alike
          "signing"

          # NOTE: lets the peer encrypt a secret with the public key, only rsa
          # key exchange does that, ecdsa keys cannot encrypt, so it is unused
          # with the ecdsa keys here
          "key encipherment"

          # NOTE: actual use case most of the time
          "client auth"
        ];
      };

      cas.kubernetes = {
        root.commonName = lib.mkDefault "kubernetes-ca";
        leaves = lib.mkMerge [
          (lib.mkIf isMaster {
            apiserver = {
              commonName = "kube-apiserver";
              hosts = lib.unique (
                [
                  "kubernetes"
                  "kubernetes.default"
                  "kubernetes.default.svc"
                  "kubernetes.default.svc.${k8sCfg.addons.dns.clusterDomain}"
                  "127.0.0.1"
                  "::1"
                  "localhost"
                  config.networking.hostName
                  config.networking.fqdnOrHostName
                ]
                ++ map firstServiceIp (lib.splitString "," k8sCfg.apiserver.serviceClusterIpRange)
                ++ hostAddresses
                ++ lib.optional (k8sCfg.apiserver.advertiseAddress != null) k8sCfg.apiserver.advertiseAddress
                ++ k8sCfg.apiserver.extraSANs
              );
              usages = [
                "signing"
                "key encipherment"
                "server auth"
              ];
              sops = {
                owner = "kubernetes";
                restartUnits = [ "kube-apiserver.service" ];
              };
            };
            apiserverKubeletClient = {
              commonName = "system:kube-apiserver";
              sops = {
                owner = "kubernetes";
                restartUnits = [ "kube-apiserver.service" ];
              };
            };
            serviceAccount = {
              commonName = "system:service-account-signer";
              # NOTE: tokens are checked against this exact key, not a CA, so
              # every apiserver must sign and verify with the same
              shared = true;
              usages = [
                "signing"
                "key encipherment"
              ];
              sops = {
                owner = "kubernetes";
                restartUnits = [
                  "kube-apiserver.service"
                  "kube-controller-manager.service"
                ];
              };
            };
            controllerManagerClient = {
              commonName = "system:kube-controller-manager";
              sops = {
                owner = "kubernetes";
                restartUnits = [ "kube-controller-manager.service" ];
              };
            };
            schedulerClient = {
              commonName = "system:kube-scheduler";
              sops = {
                owner = "kubernetes";
                restartUnits = [ "kube-scheduler.service" ];
              };
            };
            addonManager = {
              commonName = "system:kube-addon-manager";
              sops = {
                owner = "kubernetes";
                restartUnits = [ "kube-addon-manager.service" ];
              };
            };
            admin = {
              commonName = "cluster-admin";
              names.O = "system:masters";
              sops = {
                owner = "root";
                restartUnits = [ ];
              };
            };
          })

          # NOTE: a master runs these too, tainted so it gets no pods, the
          # apiserver only reaches pods and services through them
          (lib.mkIf k8sCfg.kubelet.enable {
            kubelet = {
              commonName = k8sCfg.kubelet.hostname;
              hosts = lib.unique (
                [
                  k8sCfg.kubelet.hostname
                  config.networking.hostName
                  config.networking.fqdnOrHostName
                  "127.0.0.1"
                  "::1"
                  "localhost"
                ]
                ++ hostAddresses
                ++ lib.optionals (k8sCfg.kubelet.nodeIp != null) (lib.splitString "," k8sCfg.kubelet.nodeIp)
              );
              usages = [
                "signing"
                "key encipherment"
                "server auth"
              ];
              sops = {
                owner = "root";
                restartUnits = [ "kubelet.service" ];
              };
            };
            kubeletClient = {
              commonName = "system:node:${k8sCfg.kubelet.hostname}";
              names.O = "system:nodes";
              sops = {
                owner = "root";
                restartUnits = [ "kubelet.service" ];
              };
            };
          })

          (lib.mkIf k8sCfg.proxy.enable {
            proxyClient = {
              commonName = "system:kube-proxy";
              sops = {
                owner = "root";
                restartUnits = [ "kube-proxy.service" ];
              };
            };
          })

          (lib.mkIf k8sCfg.flannel.enable {
            flannelClient = {
              commonName = "flannel-client";
              sops = {
                owner = "root";
                restartUnits = [ "flannel.service" ];
              };
            };
          })
        ];
      };

      # NOTE: its only leaf cert lets the apiserver pass the user of a request
      # on to an aggregated api like metrics-server. Anyone with a leaf cert of
      # this CA can pose as any user there, so it must not sign anything else
      cas.frontProxy = lib.mkIf isMaster {
        root.commonName = lib.mkDefault "kubernetes-front-proxy-ca";
        leaves.client = {
          commonName = "front-proxy-client";
          sops = {
            owner = "kubernetes";
            restartUnits = [ "kube-apiserver.service" ];
          };
        };
      };

      cas.etcd = lib.mkIf isMaster {
        root.commonName = lib.mkDefault "etcd-ca";
        leaves = {
          server = {
            commonName = "etcd";
            hosts = lib.unique (
              [
                "127.0.0.1"
                "::1"
                "localhost"
                config.networking.hostName
                config.networking.fqdnOrHostName
              ]
              ++ map libSinan.urlToHost (
                config.services.etcd.advertiseClientUrls ++ config.services.etcd.initialAdvertisePeerUrls
              )
              ++ hostAddresses
            );
            usages = [
              "signing"
              "key encipherment"
              "server auth"
              # NOTE: also the peer cert, so it is a client cert too
              "client auth"
            ];
            sops = {
              owner = "etcd";
              restartUnits = [ "etcd.service" ];
            };
          };
          client = {
            commonName = "etcd-client";
            sops = {
              owner = "kubernetes";
              restartUnits = [ "kube-apiserver.service" ];
            };
          };
        };
      };
    };

    services.kubernetes = {
      # NOTE: cert toolkit gives prod ready alternative
      easyCerts = lib.mkForce false;
      caFile = lib.mkDefault k8sCa.root.certPath;
      apiserverAddress = lib.mkOverride (mkDefaultPriority - 100) (
        if isMaster then
          libSinan.hostToUrl "127.0.0.1" k8sCfg.apiserver.securePort
        else
          throw "sinan.k8s: set services.kubernetes.apiserverAddress on workers, or enable sinan.k8s.kubeVip"
      );
      clusterCidr = lib.mkDefault (
        lib.concatStringsSep "," ([ cfg.ipv4.podCidr ] ++ lib.optional cfg.ipv6.enable cfg.ipv6.podCidr)
      );

      apiserver = lib.mkMerge [
        {
          serviceClusterIpRange = lib.mkDefault (
            lib.concatStringsSep "," (
              [ cfg.ipv4.serviceCidr ] ++ lib.optional cfg.ipv6.enable cfg.ipv6.serviceCidr
            )
          );
        }

        (lib.mkIf isMaster {
          tlsCertFile = k8sCa.leaves.apiserver.certPath;
          tlsKeyFile = k8sCa.leaves.apiserver.keyPath;
          clientCaFile = k8sCa.root.certPath;
          kubeletClientCaFile = k8sCa.root.certPath;
          kubeletClientCertFile = k8sCa.leaves.apiserverKubeletClient.certPath;
          kubeletClientKeyFile = k8sCa.leaves.apiserverKubeletClient.keyPath;
          proxyClientCertFile = frontProxyCa.leaves.client.certPath;
          proxyClientKeyFile = frontProxyCa.leaves.client.keyPath;
          # NOTE: upstream has no options for these, without them an aggregated
          # api cannot tell who sent a request
          extraOpts = lib.concatStringsSep " " [
            "--requestheader-client-ca-file=${frontProxyCa.root.certPath}"
            "--requestheader-allowed-names=${frontProxyCa.leaves.client.commonName}"
            "--requestheader-username-headers=X-Remote-User"
            "--requestheader-group-headers=X-Remote-Group"
            "--requestheader-extra-headers-prefix=X-Remote-Extra-"
          ];
          serviceAccountKeyFile = k8sCa.leaves.serviceAccount.certPath;
          serviceAccountSigningKeyFile = k8sCa.leaves.serviceAccount.keyPath;
          etcd = {
            servers = lib.mkOverride (mkDefaultPriority - 1) (
              map (member: libSinan.hostToUrl member 2379) cfg.etcdMembers
            );
            caFile = etcdCa.root.certPath;
            certFile = etcdCa.leaves.client.certPath;
            keyFile = etcdCa.leaves.client.keyPath;
          };
        })
      ];

      controllerManager = lib.mkIf isMaster {
        serviceAccountKeyFile = k8sCa.leaves.serviceAccount.keyPath;
        rootCaFile = k8sCa.root.certPath;
        kubeconfig = clientCert k8sCa.leaves.controllerManagerClient;
      };

      scheduler = lib.mkIf isMaster {
        kubeconfig = clientCert k8sCa.leaves.schedulerClient;
      };

      kubelet = lib.mkIf k8sCfg.kubelet.enable {
        clientCaFile = k8sCa.root.certPath;
        tlsCertFile = k8sCa.leaves.kubelet.certPath;
        tlsKeyFile = k8sCa.leaves.kubelet.keyPath;
        kubeconfig = clientCert k8sCa.leaves.kubeletClient;
        extraConfig = {
          shutdownGracePeriod = lib.mkDefault "30s";
          shutdownGracePeriodCriticalPods = lib.mkDefault "10s";
        };

        # NOTE: upstream taints master only nodes with unschedulable and the
        # node-role master key kubeadm dropped in 1.25, keep only its
        # control-plane successor that charts tolerate
        unschedulable = lib.mkOverride (mkDefaultPriority - 1) false;
        taints.master = lib.mkIf (!lib.elem "node" k8sCfg.roles) {
          key = lib.mkForce "node-role.kubernetes.io/control-plane";
          value = lib.mkForce "";
        };
      };

      proxy = lib.mkIf k8sCfg.proxy.enable {
        kubeconfig = clientCert k8sCa.leaves.proxyClient;
      };
    };

    services.flannel = lib.mkIf k8sCfg.flannel.enable {
      kubeconfig = mkKubeconfig "flannel" k8sCa.leaves.flannelClient;
    };

    services.etcd = lib.mkIf isMaster ({
      name = config.networking.hostName;
      advertiseClientUrls = [ (libSinan.hostToUrl config.networking.hostName 2379) ];
      initialAdvertisePeerUrls = [ (libSinan.hostToUrl config.networking.hostName 2380) ];
      initialCluster = map (member: "${member}=${libSinan.hostToUrl member 2380}") cfg.etcdMembers;
      certFile = lib.mkDefault etcdCa.leaves.server.certPath;
      keyFile = lib.mkDefault etcdCa.leaves.server.keyPath;
      trustedCaFile = lib.mkDefault etcdCa.root.certPath;
      peerCertFile = lib.mkDefault etcdCa.leaves.server.certPath;
      peerKeyFile = lib.mkDefault etcdCa.leaves.server.keyPath;
      peerTrustedCaFile = lib.mkDefault etcdCa.root.certPath;
    });

    # NOTE: UPSTREAM: etcd is Type=notify, wait for it
    systemd.services.kube-apiserver =
      lib.mkIf (k8sCfg.apiserver.enable && config.services.etcd.enable)
        {
          wants = [ "etcd.service" ];
          after = [ "etcd.service" ];
        };

    systemd.services.kube-addon-manager = lib.mkIf (isMaster && k8sCfg.addonManager.enable) {
      environment.KUBECONFIG = mkKubeconfig "addon-manager" k8sCa.leaves.addonManager;
      # NOTE: the bootstrap addons hold the rbac rules the addon manager itself
      # needs, so they are applied as cluster admin, which upstream only does
      # with easyCerts
      serviceConfig.ExecStartPre =
        let
          addons = k8sCfg.addonManager.bootstrapAddons;
          # NOTE: kubectl refuses an applyset whose objects sit in
          # another namespace than its parent
          byNamespace = lib.groupBy (name: addons.${name}.metadata.namespace or "kube-system") (
            lib.attrNames addons
          );
          namespaces =
            lib.optional (byNamespace ? kube-system) "kube-system"
            ++ lib.remove "kube-system" (lib.attrNames byNamespace);
          applyNamespace = namespace: ''
            ${kubectl} apply --validate=false --prune \
              --server-side --force-conflicts --field-manager=bootstrap-addons \
              --applyset=bootstrap-addons --namespace ${namespace} \
              ${lib.concatMapStringsSep " " (
                name: "--filename ${pkgs.writeText "${name}.json" (lib.toJSON addons.${name})}"
              ) byNamespace.${namespace}}
          '';
          bootstrap = pkgs.writeShellScript "kube-addon-manager-bootstrap" ''
            set -e
            export KUBECONFIG=${adminKubeconfig}
            # NOTE: without this runs as root with the HOME of the kubernetes
            # user, kubectl would cache into a root owned ~/.kube there that
            # kube-addons can no longer read its kuberc from
            export HOME=/root

            until ${kubectl} cluster-info > /dev/null 2>&1; do
              sleep 1
            done

            export KUBECTL_APPLYSET=true
            ${lib.concatMapStrings applyNamespace namespaces}
          '';
        in
        lib.mkIf (addons != { }) [ "+${bootstrap}" ];
    };

    environment = {
      systemPackages = [ k8sCfg.package ];
      # NOTE: it's okay, the KUBECONFIG only contains path to keys
      etc."kubernetes/cluster-admin.kubeconfig" = lib.mkIf isMaster {
        source = adminKubeconfig;
      };
      variables.KUBECONFIG = lib.mkIf isMaster (lib.mkDefault "/etc/kubernetes/cluster-admin.kubeconfig");
    };
    systemd.tmpfiles.rules = lib.mkIf isMaster [
      "L+ /root/.kube/config - - - - /etc/kubernetes/cluster-admin.kubeconfig"
    ];

    # NOTE: upstream already opens the flannel ports
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      lib.optionals isMaster [
        k8sCfg.apiserver.securePort
        # NOTE: etcd client and peer
        2379
        2380
      ]
      ++ lib.optional k8sCfg.kubelet.enable k8sCfg.kubelet.port
    );
  };
}
