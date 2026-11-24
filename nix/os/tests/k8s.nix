{
  lib,
  runCommand,
  nixos,
  self,
}:
let
  /**
    Evaluate a NixOS system that imports the k8s module of this flake,
    the way a host gets it.

    # Inputs

    `module`

    : NixOS module with the settings of the host

    # Type

    ```
    evalK8s :: Module -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `evalK8s` usage example

    ```nix
    (evalK8s { sinan.k8s.enable = true; }).services.kubernetes.easyCerts
    => false
    ```

    :::
  */
  evalK8s =
    module:
    (nixos {
      imports = [
        self.nixosModules.k8s
        module
      ];
      networking.hostName = lib.mkDefault "test-node";
    }).config;

  failures = lib.runTests {
    # NOTE: a worker must not get the keys of the control plane
    testWorkerHasNoMasterCerts = {
      expr =
        let
          config = evalK8s {
            sinan.k8s.enable = true;
            services.kubernetes.roles = [ "node" ];
          };
        in
        {
          cas = lib.attrNames config.sinan.certToolkit.cas;
          leaves = lib.attrNames config.sinan.certToolkit.cas.kubernetes.leaves;
        };
      expected = {
        cas = [ "kubernetes" ];
        leaves = [
          "flannelClient"
          "kubelet"
          "kubeletClient"
          "proxyClient"
        ];
      };
    };
  };
in
assert lib.assertMsg (failures == [ ]) "k8s tests failed: ${lib.toJSON failures}";
runCommand "k8s-tests" { } "touch $out"
