{
  lib,
  testers,
  self,
}:
let
  masters = [
    "master1"
    "master2"
    "master3"
  ];
  workers = [
    "worker1"
    "worker2"
  ];
  # NOTE: a free addresses on eth1, the vms take 192.168.1.1-5
  virtualIp = "192.168.1.69";
  loadBalancerRange = {
    first = 200;
    last = 210;
  };

  common =
    { config, nodes, ... }:
    {
      key = "common.k8s.tests.infra.sinanmohd.com";
      imports = [ self.nixosModules.k8s ];

      sinan.k8s = {
        enable = true;
        openFirewall = true;
        kubeVip = {
          enable = true;
          address = virtualIp;
          interface = "eth1";
          loadBalancerRange = "192.168.1.${toString loadBalancerRange.first}-192.168.1.${toString loadBalancerRange.last}";
        };
      };
      sinan.certToolkit = {
        createCerts = true;
        clusterFrom = lib.mkIf (config.networking.hostName != "master1") nodes.master1.sinan.certToolkit;
      };
      services.kubernetes = {
        masterAddress = "master1";
        kubelet.nodeIp = config.networking.primaryIPAddress;
      };
      # NOTE: eth0 is the same qemu user network on every vm,
      # the vms only reach each other over eth1
      services.flannel.iface = "eth1";

      # NOTE: vm-k8s-5 test went down to 132s -> 85s
      virtualisation.cores = 2;
    };

  master =
    { config, ... }:
    {
      imports = [ common ];
      services.kubernetes = {
        roles = [ "master" ];
        apiserver.advertiseAddress = config.networking.primaryIPAddress;
      };
    };

  # NOTE: one of the masters of the etcd cluster in `masters`
  clusteredMaster =
    { config, ... }:
    let
      name = config.networking.hostName;
    in
    {
      imports = [ master ];
      services.kubernetes.apiserver.etcd.servers = map (master: "https://${master}:2379") masters;
      services.etcd = {
        # NOTE: upstream names every member after masterAddress
        inherit name;
        advertiseClientUrls = [ "https://${name}:2379" ];
        initialAdvertisePeerUrls = [ "https://${name}:2380" ];
        initialCluster = map (master: "${master}=https://${master}:2380") masters;
      };
    };

  worker = {
    imports = [ common ];
    services.kubernetes.roles = [ "node" ];
  };

  /**
    Build a vm test that boots a cluster and waits until the control
    plane answers on every master and every node reports Ready. It then
    checks that only the front proxy leaf cert may pass a user on to the
    apiserver and that masters can reach pods over the pod network.

    # Inputs

    `args`

    : An attribute set containing:

      `name`

      : Name of the test

      `nodes`

      : The vms of the cluster, masters are named `master<n>`

    # Type

    ```
    mkTest :: { name :: String; nodes :: { [String] :: Module }; } -> Derivation
    ```
  */
  mkTest =
    {
      name,
      nodes,
    }:
    testers.runNixOSTest {
      inherit name nodes;
      interactive = {
        sshBackdoor.enable = true;
        defaults =
          { config, pkgs, ... }:
          {
            environment.systemPackages = lib.mkIf (lib.elem "master" config.services.kubernetes.roles) (
              with pkgs;
              [
                k9s
                btop
                neovim
                curl
              ]
            );
          };
      };

      testScript =
        { nodes, ... }:
        let
          cas = nodes.master1.sinan.certToolkit.cas;
          frontProxy = cas.frontProxy.leaves.client;
          kubelet = cas.kubernetes.leaves.kubeletClient;
        in
        ''
          start_all()

          masters = [machine for machine in machines if machine.name.startswith("master")]
          for master in masters:
              master.wait_for_unit("etcd.service")
          for master in masters:
              master.wait_for_unit("kube-apiserver.service")
              master.wait_until_succeeds("kubectl cluster-info")
          master1.wait_until_succeeds("kubectl get --raw /healthz | grep ok")

          for machine in machines:
              master1.wait_until_succeeds(f"kubectl get node {machine.name} | grep --word-regexp Ready")


          def status_as_admin(cert: str, key: str) -> str:
              """Ask the apiserver for the namespaces, claiming to be an admin in the headers"""
              return master1.succeed(
                  "curl --silent --output /dev/null --write-out '%{http_code}'"
                  " --cacert ${cas.kubernetes.root.certPath}"
                  f" --cert {cert} --key {key}"
                  " --header 'X-Remote-User: someone'"
                  " --header 'X-Remote-Group: system:masters'"
                  " https://master1:6443/api/v1/namespaces"
              )


          with subtest("only the front proxy leaf cert may pass a user on"):
              assert status_as_admin("${frontProxy.certPath}", "${frontProxy.keyPath}") == "200"
              assert status_as_admin("${kubelet.certPath}", "${kubelet.keyPath}") == "403"
              master1.succeed(
                  "kubectl --namespace kube-system get configmap extension-apiserver-authentication"
                  " --output jsonpath='{.data.requestheader-client-ca-file}' | grep BEGIN"
              )


          with subtest("masters can reach pods over the pod network"):
              pod_ip = (
                  "kubectl --namespace kube-system get pods --selector k8s-app=kube-dns"
                  " --output jsonpath='{.items[0].status.podIP}'"
              )
              for master in masters:
                  master.wait_until_succeeds(f"curl --silent --fail http://$({pod_ip}):10054/health")


          with subtest("the apiserver answers on the virtual ip"):
              master1.wait_until_succeeds(
                  "kubectl --server https://${virtualIp}:6443 get --raw /healthz | grep ok"
              )


          with subtest("a LoadBalancer service gets an ip from the pool"):
              master1.succeed(
                  "kubectl --namespace kube-system expose deployment coredns"
                  " --name coredns-health --type LoadBalancer --port 10054"
              )
              lb_ip = (
                  "kubectl --namespace kube-system get service coredns-health"
                  " --output jsonpath='{.status.loadBalancer.ingress[0].ip}'"
              )
              master1.wait_until_succeeds(f"{lb_ip} | grep .")
              ip = master1.succeed(lb_ip).strip()
              assert ip.startswith("192.168.1.")
              assert ${toString loadBalancerRange.first} <= int(ip.rsplit(".", 1)[1]) <= ${toString loadBalancerRange.last}
              for machine in machines:
                  machine.wait_until_succeeds(f"curl --silent --fail http://{ip}:10054/health")


          if len(masters) > 1:
              with subtest("the virtual ip moves when its master goes down"):
                  holder = next(
                      master for master in masters
                      if master.execute("ip -4 address show eth1 | grep --fixed-strings ' ${virtualIp}/'")[0] == 0
                  )
                  assert isinstance(holder, QemuMachine)
                  holder.crash()
                  survivor = next(master for master in masters if master is not holder)
                  survivor.wait_until_succeeds(
                      "kubectl --server https://${virtualIp}:6443 get --raw /healthz | grep ok"
                  )
        '';
    };
in
{
  # NOTE: single node cluster that is both master and worker
  vm-k8s-1 = mkTest {
    name = "vm-k8s-1";
    nodes.master1 = {
      imports = [
        master
        worker
      ];
    };
  };

  # NOTE: three masters sharing etcd cluster, each also a worker
  vm-k8s-3 = mkTest {
    name = "vm-k8s-3";
    nodes = lib.genAttrs masters (_: {
      imports = [
        clusteredMaster
        worker
      ];
    });
  };

  # NOTE: three masters sharing etcd cluster and two workers
  vm-k8s-5 = mkTest {
    name = "vm-k8s-5";
    nodes = lib.genAttrs masters (_: clusteredMaster) // lib.genAttrs workers (_: worker);
  };
}
