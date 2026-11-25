{ lib }:
rec {
  /**
    Build the cfssl CSR for a root or leaf cert. cfssl ignores `expiry` and
    `usages` in a CSR, a CA takes its expiry from `ca.expiry` (see
    `mkRootCsrFile`) and a leaf cert takes both from its signing config (see
    `mkSigningConfigFile`). Unset subject names are left out.

    # Inputs

    `cert`

    : Evaluated root or leaf cert options

    # Type

    ```
    mkCsr :: AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `mkCsr` usage example

    ```nix
    mkCsr {
      commonName = "etcd";
      key = { algo = "ecdsa"; size = 256; };
      hosts = [ "h1" "127.0.0.1" ];
      names = { C = "IN"; ST = null; L = null; O = null; OU = null; };
      expiry = "720h";
      usages = [ "server auth" ];
    }
    => {
      CN = "etcd";
      key = { algo = "ecdsa"; size = 256; };
      hosts = [ "h1" "127.0.0.1" ];
      names = [ { C = "IN"; } ];
    }
    ```

    :::
  */
  mkCsr = cert: {
    CN = cert.commonName;
    inherit (cert)
      key
      hosts
      ;
    names = [ (lib.filterAttrs (_: value: value != null) cert.names) ];
  };

  /**
    Write the cfssl CSR for the root cert of a CA to the store.

    # Inputs

    `root`

    : Evaluated `sinan.certToolkit.cas.<ca>.root`

    # Type

    ```
    mkRootCsrFile :: AttrSet -> String
    ```
  */
  mkRootCsrFile =
    root:
    let
      csr = mkCsr root // {
        ca.expiry = root.expiry;
      };
    in
    lib.toFile "csr-${root.id}.json" (lib.toJSON csr);

  /**
    Write the cfssl CSR for a leaf cert to the store.

    # Inputs

    `leaf`

    : Evaluated `sinan.certToolkit.cas.<ca>.leaves.<name>`

    # Type

    ```
    mkLeafCsrFile :: AttrSet -> String
    ```
  */
  mkLeafCsrFile = leaf: lib.toFile "csr-${leaf.id}.json" (lib.toJSON (mkCsr leaf));

  /**
    Write the cfssl signing config for a leaf cert to the store, it holds
    the expiry and usages the CA signs the leaf with.

    # Inputs

    `leaf`

    : Evaluated `sinan.certToolkit.cas.<ca>.leaves.<name>`

    # Type

    ```
    mkSigningConfigFile :: AttrSet -> String
    ```
  */
  mkSigningConfigFile =
    leaf:
    lib.toFile "signing-${leaf.id}.json" (
      lib.toJSON {
        signing.default = {
          inherit (leaf) expiry usages;
        };
      }
    );
}
