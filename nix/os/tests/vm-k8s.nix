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

  k8sApiIpHA = "192.168.1.69";
  k8sApiIpv6HA = "2001:db8:1::69";

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
        ipv6.enable = true;
        cilium.enable = true;
        kubeVip = {
          enable = true;
          address = k8sApiIpHA;
          addressIpv6 = k8sApiIpv6HA;
          interface = "eth1";
          loadBalancerRange = "192.168.1.${toString loadBalancerRange.first}-192.168.1.${toString loadBalancerRange.last}";
          loadBalancerRangeIpv6 = "2001:db8:1::${toString loadBalancerRange.first}-2001:db8:1::${toString loadBalancerRange.last}";
        };
      };
      sinan.certToolkit = {
        createCerts = true;
        clusterFrom = lib.mkIf (config.networking.hostName != "master1") nodes.master1.sinan.certToolkit;
      };
      services.kubernetes = {
        masterAddress = "master1";
        kubelet.nodeIp = "${config.networking.primaryIPAddress},${config.networking.primaryIPv6Address}";
      };

      virtualisation = {
        # NOTE: vm-k8s-5 test went down to 132s -> 85s
        cores = 2;
        # NOTE: the seeded images are getting big with cillium
        diskSize = 6 * 1024;
        # NOTE: room for the cilium agent next to the control plane
        memorySize = 2 * 1024;
      };
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
          import json

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


          def url(address: str, port: int | str) -> str:
              """An http url, with the brackets an IPv6 address needs"""
              host = f"[{address}]" if ":" in address else address
              return f"http://{host}:{port}"


          def pod_ips() -> list[str]:
              """The addresses of a coredns pod, empty until it has them"""
              return master1.succeed(
                  "kubectl --namespace kube-system get pods --selector k8s-app=kube-dns"
                  " --output jsonpath='{.items[0].status.podIPs[*].ip}'"
              ).split()


          with subtest("masters can reach pods over the pod network on both IPv4 and IPv6"):
              retry(lambda _: len(pod_ips()) == 2)
              addresses = pod_ips()
              assert any(":" in address for address in addresses), addresses
              for master in masters:
                  for address in addresses:
                      master.wait_until_succeeds(f"curl --silent --fail {url(address, 10054)}/health")


          def all_pods_ready(last_try: bool) -> bool:
              """Whether every pod is Ready, or Succeeded like finished jobs"""
              pods = master1.succeed(
                  "kubectl get pods --all-namespaces --output jsonpath='{range .items[*]}"
                  "{.metadata.namespace}/{.metadata.name} {.status.phase}"
                  " {.status.conditions[?(@.type==\"Ready\")].status}{\"\\n\"}{end}'"
              ).strip().splitlines()
              not_ready = [
                  pod for pod in pods
                  if pod.split()[1] != "Succeeded" and pod.split()[2:] != ["True"]
              ]
              if last_try:
                  print("pods not ready:", not_ready)
              return not_ready == []


          with subtest("every pod is ready or has succeeded"):
              retry(all_pods_ready)


          with subtest("the apiserver answers on both virtual ips"):
              for address in ["${k8sApiIpHA}", "[${k8sApiIpv6HA}]"]:
                  master1.wait_until_succeeds(
                      f"kubectl --server https://{address}:6443 get --raw /healthz | grep ok"
                  )


          def dual_stack_service(name: str, service_type: str) -> None:
              """A coredns health service with an address of each family"""
              manifest = json.dumps({
                  "apiVersion": "v1",
                  "kind": "Service",
                  "metadata": {"name": name, "namespace": "kube-system"},
                  "spec": {
                      "type": service_type,
                      "ipFamilyPolicy": "RequireDualStack",
                      "ipFamilies": ["IPv4", "IPv6"],
                      "selector": {"k8s-app": "kube-dns"},
                      "ports": [{"port": 10054, "targetPort": 10054}],
                  },
              })
              master1.succeed(f"kubectl apply --filename - <<'EOF'\n{manifest}\nEOF")


          def load_balancer_ips(machine: BaseMachine) -> list[str]:
              """The addresses of the coredns-health service, empty until it has them"""
              return machine.succeed(
                  "kubectl --namespace kube-system get service coredns-health"
                  " --output jsonpath='{.status.loadBalancer.ingress[*].ip}'"
              ).split()


          with subtest("a LoadBalancer service gets an ip of each family from the pools"):
              dual_stack_service("coredns-health", "LoadBalancer")
              retry(lambda _: len(load_balancer_ips(master1)) == 2)
              lb_addresses = load_balancer_ips(master1)
              ipv4 = next(address for address in lb_addresses if ":" not in address)
              ipv6 = next(address for address in lb_addresses if ":" in address)
              assert ipv4.startswith("192.168.1.")
              assert ${toString loadBalancerRange.first} <= int(ipv4.rsplit(".", 1)[1]) <= ${toString loadBalancerRange.last}
              assert ipv6.startswith("2001:db8:1::")
              for machine in machines:
                  for address in lb_addresses:
                      machine.wait_until_succeeds(f"curl --silent --fail {url(address, 10054)}/health")


          with subtest("a NodePort service answers on every node and family, test firewall rules"):
              dual_stack_service("coredns-nodeport", "NodePort")
              node_port = master1.succeed(
                  "kubectl --namespace kube-system get service coredns-nodeport"
                  " --output jsonpath='{.spec.ports[0].nodePort}'"
              ).strip()
              for machine in machines:
                  # NOTE: kubelet registers the node with its eth1 addr
                  node_ips = master1.succeed(
                      f"kubectl get node {machine.name} --output"
                      " jsonpath='{.status.addresses[?(@.type==\"InternalIP\")].address}'"
                  ).split()
                  assert len(node_ips) == 2, node_ips
                  for address in node_ips:
                      master1.wait_until_succeeds(f"curl --silent --fail {url(address, node_port)}/health")


          def holds(machine: BaseMachine, address: str) -> bool:
              """Whether kube-vip announces the address from this machine"""
              return machine.execute(f"ip address show eth1 | grep --fixed-strings ' {address}/'")[0] == 0


          if len(masters) > 1:
              with subtest("the cluster keeps working when the master holding the virtual ip goes down"):
                  holder = next(master for master in masters if holds(master, "${k8sApiIpHA}"))
                  assert holds(holder, "${k8sApiIpv6HA}")
                  lb_addresses = load_balancer_ips(master1)
                  assert isinstance(holder, QemuMachine)
                  holder.crash()
                  survivors = [master for master in masters if master is not holder]

                  for address in ["${k8sApiIpHA}", "[${k8sApiIpv6HA}]"]:
                      survivors[0].wait_until_succeeds(
                          f"kubectl --server https://{address}:6443 get --raw /healthz | grep ok"
                      )

                  # NOTE: the LoadBalancer ip from the subtest above moves to a
                  # survivor once its lease expires, check that
                  for address in lb_addresses:
                      retry(lambda _: any(holds(master, address) for master in survivors))

                  # NOTE: the agents reach the apiserver through the virtual ip,
                  # every survivor has to reconnect once it moves, cilium-dbg
                  # status in its agent checks that
                  for master in survivors:
                      agent = (
                          "kubectl --namespace kube-system get pods --selector k8s-app=cilium"
                          f" --field-selector spec.nodeName={master.name} --output name"
                      )
                      master.wait_until_succeeds(
                          f"kubectl --namespace kube-system exec $({agent}) --container cilium-agent"
                          " -- cilium-dbg status --brief"
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
      # NOTE: the chart never puts two operators on the same node
      sinan.k8s.cilium.values.operator.replicas = 1;
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
