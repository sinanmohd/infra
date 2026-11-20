{
  lib,
  runCommand,
}:
let
  /**
    Evaluate the cert toolkit on its own, outside of a NixOS system, with
    stand ins for the NixOS and sops-nix options it reads.

    # Inputs

    `settings`

    : Value of the `certToolkit` option

    # Type

    ```
    evalToolkit :: AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `evalToolkit` usage example

    ```nix
    (evalToolkit { defaults.expiry = "42h"; }).caDefaults.expiry
    => "42h"
    ```

    :::
  */
  evalToolkit =
    settings:
    (lib.evalModules {
      modules = [
        ../modules/k8s/modules/cert-toolkit
        {
          options.networking.hostName = lib.mkOption { default = "host"; };
          options.sops.secrets = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
          config._module.args.inputsSinan.self.outPath = "/nonexistent";
          config.certToolkit = settings;
        }
      ];
    }).config.certToolkit;

  failures = lib.runTests {
    testDir = {
      expr = (evalToolkit { dir = "./my-dir"; }).dir;
      expected = "./my-dir";
    };

    testCaDefaultsDeriveFromDefaults = {
      expr = (evalToolkit { defaults.expiry = "42h"; }).caDefaults.expiry;
      expected = "42h";
    };

    testCaDefaultsWithoutDefaults = {
      expr = (evalToolkit { caDefaults.expiry = "42h"; }).caDefaults.expiry;
      expected = "42h";
    };

    testCaDefaultNamesMergeWithDefaultNames = {
      expr =
        let
          toolkit = evalToolkit {
            defaults.names.L = "CH";
            caDefaults.names.O = "MyOrga";
          };
        in
        {
          inherit (toolkit.caDefaults.names) L O;
        };
      expected = {
        L = "CH";
        O = "MyOrga";
      };
    };

    testCertDefaultNamesMergeWithDefaultNames = {
      expr =
        let
          toolkit = evalToolkit {
            defaults.names.L = "CH";
            certDefaults.names.O = "MyOrga";
          };
        in
        {
          inherit (toolkit.certDefaults.names) L O;
        };
      expected = {
        L = "CH";
        O = "MyOrga";
      };
    };

    testDefaultsReachCertDefaultsOfCa = {
      expr =
        (evalToolkit {
          defaults.expiry = "42h";
          cas.my-ca = { };
        }).cas.my-ca.certDefaults.expiry;
      expected = "42h";
    };

    testCaDefaultsReachRoot = {
      expr =
        (evalToolkit {
          caDefaults.expiry = "42h";
          cas.my-ca.root = { };
        }).cas.my-ca.root.expiry;
      expected = "42h";
    };

    testCertDefaultsOfCaReachCerts = {
      expr =
        (evalToolkit {
          cas.my-ca = {
            certDefaults.expiry = "42h";
            certs.my-cert = { };
          };
        }).cas.my-ca.certs.my-cert.expiry;
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
            certDefaults.names = {
              ST = "Bern";
              L = "BAD";
              O = "BAD";
            };
            cas.my-ca = {
              certDefaults.names = {
                L = "Thun";
                O = "BAD";
              };
              certs.my-cert.names.O = "MyOrg";
            };
          };
        in
        {
          inherit (toolkit.cas.my-ca.certs.my-cert.names)
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

    testSopsSettingsMergePerKey = {
      expr =
        (evalToolkit {
          defaults.sops = {
            owner = "root";
            mode = "0440";
          };
          cas.my-ca.certs.my-cert.sops.owner = "etcd";
        }).cas.my-ca.certs.my-cert.sops;
      expected = {
        owner = "etcd";
        mode = "0440";
      };
    };
  };
in
assert lib.assertMsg (failures == [ ]) "cert toolkit tests failed: ${builtins.toJSON failures}";
runCommand "cert-toolkit-tests" { } "touch $out"
