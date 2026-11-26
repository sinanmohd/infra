{
  lib,
  runCommand,
  nixos,
  self,
}:
let
  /**
    Evaluate the cert toolkit in a NixOS system that imports the k8s
    module of this flake, the way a host gets it.

    # Inputs

    `settings`

    : Value of the `sinan.certToolkit` option

    # Type

    ```
    evalToolkit :: AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `evalToolkit` usage example

    ```nix
    (evalToolkit { defaults.expiry = "42h"; }).rootDefaults.expiry
    => "42h"
    ```

    :::
  */
  evalToolkit =
    settings:
    (nixos {
      imports = [ self.nixosModules.k8s ];
      sinan.certToolkit = settings;
    }).config.sinan.certToolkit;

  failures = lib.runTests {
    testRootDefaultsToThisFlake = {
      expr = (evalToolkit { }).root;
      expected = self.outPath;
    };

    testDir = {
      expr = (evalToolkit { dir = "./my-dir"; }).dir;
      expected = "./my-dir";
    };

    testRootDefaultsDeriveFromDefaults = {
      expr = (evalToolkit { defaults.expiry = "42h"; }).rootDefaults.expiry;
      expected = "42h";
    };

    testRootDefaultsWithoutDefaults = {
      expr = (evalToolkit { rootDefaults.expiry = "42h"; }).rootDefaults.expiry;
      expected = "42h";
    };

    testRootDefaultNamesMergeWithDefaultNames = {
      expr =
        let
          toolkit = evalToolkit {
            defaults.names.L = "CH";
            rootDefaults.names.O = "MyOrga";
          };
        in
        {
          inherit (toolkit.rootDefaults.names) L O;
        };
      expected = {
        L = "CH";
        O = "MyOrga";
      };
    };

    testLeafDefaultNamesMergeWithDefaultNames = {
      expr =
        let
          toolkit = evalToolkit {
            defaults.names.L = "CH";
            leafDefaults.names.O = "MyOrga";
          };
        in
        {
          inherit (toolkit.leafDefaults.names) L O;
        };
      expected = {
        L = "CH";
        O = "MyOrga";
      };
    };

    testDefaultsReachLeafDefaultsOfCa = {
      expr =
        (evalToolkit {
          defaults.expiry = "42h";
          cas.my-ca = { };
        }).cas.my-ca.leafDefaults.expiry;
      expected = "42h";
    };

    testRootDefaultsReachRoot = {
      expr =
        (evalToolkit {
          rootDefaults.expiry = "42h";
          cas.my-ca.root = { };
        }).cas.my-ca.root.expiry;
      expected = "42h";
    };

    testLeafDefaultsOfCaReachLeaves = {
      expr =
        (evalToolkit {
          cas.my-ca = {
            leafDefaults.expiry = "42h";
            leaves.my-cert = { };
          };
        }).cas.my-ca.leaves.my-cert.expiry;
      expected = "42h";
    };

    testMostSpecificNameWins = {
      expr =
        let
          toolkit = evalToolkit {
            defaults.names = {
              C = "CH";
              ST = "BAD";
              L = "BAD";
              O = "BAD";
            };
            leafDefaults.names = {
              ST = "Bern";
              L = "BAD";
              O = "BAD";
            };
            cas.my-ca = {
              leafDefaults.names = {
                L = "Thun";
                O = "BAD";
              };
              leaves.my-cert.names.O = "MyOrg";
            };
          };
        in
        {
          inherit (toolkit.cas.my-ca.leaves.my-cert.names)
            C
            ST
            L
            O
            ;
        };
      expected = {
        C = "CH";
        ST = "Bern";
        L = "Thun";
        O = "MyOrg";
      };
    };

    testSharedLeafNamesNoHost = {
      expr =
        let
          leaves =
            (evalToolkit {
              dir = "certs";
              cas.my-ca.leaves = {
                mine = { };
                ours.shared = true;
              };
            }).cas.my-ca.leaves;
        in
        lib.mapAttrs (_: leaf: { inherit (leaf) id relativeCertPath relativeSopsKeyPath; }) leaves;
      expected = {
        mine = {
          id = "leaf-nixos-my-ca-mine";
          relativeCertPath = "certs/leaf/nixos/my-ca-mine.crt";
          relativeSopsKeyPath = "certs/leaf/nixos/my-ca-mine.key.sops";
        };
        ours = {
          id = "leaf-shared-my-ca-ours";
          relativeCertPath = "certs/leaf/shared/my-ca-ours.crt";
          relativeSopsKeyPath = "certs/leaf/shared/my-ca-ours.key.sops";
        };
      };
    };

    testPackageThrowsWithoutCreateCerts = {
      expr =
        let
          ca = (evalToolkit { cas.my-ca.leaves.my-cert = { }; }).cas.my-ca;
        in
        {
          root = (builtins.tryEval ca.root.package).success;
          leaf = (builtins.tryEval ca.leaves.my-cert.package).success;
        };
      expected = {
        root = false;
        leaf = false;
      };
    };

    testSopsSettingsMergePerKey = {
      expr =
        (evalToolkit {
          defaults.sops = {
            owner = "root";
            mode = "0440";
          };
          cas.my-ca.leaves.my-cert.sops.owner = "etcd";
        }).cas.my-ca.leaves.my-cert.sops;
      expected = {
        owner = "etcd";
        mode = "0440";
      };
    };
  };
in
assert lib.assertMsg (failures == [ ]) "cert toolkit tests failed: ${builtins.toJSON failures}";
runCommand "cert-toolkit-tests" { } "touch $out"
