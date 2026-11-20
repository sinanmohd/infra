{
  lib,
  writeShellApplication,
  cfssl,
  git,
  jq,
  sops,
  nixosConfigurations,
}:
let
  /**
    Build the cfssl CSR for a cert or CA. cfssl ignores `expiry` and
    `usages` in a CSR, a CA takes its expiry from `ca.expiry` (see
    `mkRootScript`) and a cert takes both from its signing config (see
    `mkLeafScript`). Unset subject names are left out.

    # Inputs

    `cert`

    : Evaluated cert or CA options

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
    Shell to encrypt the private key of a cfssl json result in `$cert`
    with sops and write the certificate next to it. Recipients come from
    the `.sops.yaml` creation rule matching `relativeSopsFile`.

    # Inputs

    `cert`

    : Evaluated cert or CA options

    # Type

    ```
    mkWriteScript :: AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `mkWriteScript` usage example

    ```nix
    mkWriteScript {
      relativePath = "certs/derived/h1/etcd-server.crt";
      relativeSopsFile = "certs/derived/h1/etcd-server.key.sops";
    }
    => ''
      mkdir --parents "$(dirname certs/derived/h1/etcd-server.crt)"
      printf '%s' "$cert" \
        | jq --raw-output .key \
        | sops encrypt --filename-override certs/derived/h1/etcd-server.key.sops --output certs/derived/h1/etcd-server.key.sops /dev/stdin
      printf '%s' "$cert" | jq --raw-output .cert > certs/derived/h1/etcd-server.crt
    ''
    ```

    :::
  */
  mkWriteScript =
    cert:
    let
      sopsFile = lib.escapeShellArg cert.relativeSopsFile;
      certFile = lib.escapeShellArg cert.relativePath;
    in
    ''
      mkdir --parents "$(dirname ${certFile})"
      printf '%s' "$cert" \
        | jq --raw-output .key \
        | sops encrypt --filename-override ${sopsFile} --output ${sopsFile} /dev/stdin
      printf '%s' "$cert" | jq --raw-output .cert > ${certFile}
    '';

  /**
    Shell to create the root cert of a CA. An existing root is kept, only
    the recipients of its key are synced with `.sops.yaml`.

    # Inputs

    `root`

    : Evaluated `certToolkit.cas.<ca>.root`

    # Type

    ```
    mkRootScript :: AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `mkRootScript` usage example

    ```nix
    mkRootScript config.certToolkit.cas.etcd.root
    => ''
      echo ca-etcd
      if [ -e certs/ca/etcd.key.sops ]; then
        sops updatekeys --yes certs/ca/etcd.key.sops
      else
        cert=$(cfssl gencert -loglevel 2 -initca /nix/store/...-csr-ca-etcd.json)
        mkdir --parents "$(dirname certs/ca/etcd.crt)"
        ...
      fi
    ''
    ```

    :::
  */
  mkRootScript =
    root:
    let
      sopsFile = lib.escapeShellArg root.relativeSopsFile;
      # NOTE: cfssl ignores `usages` for a CA
      csr = mkCsr root // {
        ca.expiry = root.expiry;
      };
      csrFile = builtins.toFile "csr-${root.id}.json" (builtins.toJSON csr);
    in
    ''
      echo ${lib.escapeShellArg root.id}
      if [ -e ${sopsFile} ]; then
        sops updatekeys --yes ${sopsFile}
      else
        cert=$(cfssl gencert -loglevel 2 -initca ${csrFile})
        ${mkWriteScript root}
      fi
    '';

  /**
    Shell to create a leaf cert signed by the root cert of its CA. The
    decrypted root key is handed to cfssl through the environment, so it
    never touches the disk.

    # Inputs

    `root`

    : Evaluated `certToolkit.cas.<ca>.root` to sign with

    `cert`

    : Evaluated `certToolkit.cas.<ca>.certs.<name>`

    # Type

    ```
    mkLeafScript :: AttrSet -> AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `mkLeafScript` usage example

    ```nix
    mkLeafScript config.certToolkit.cas.etcd.root config.certToolkit.cas.etcd.certs.server
    => ''
      echo derived-h1-etcd-server
      ca_key=$(sops decrypt certs/ca/etcd.key.sops)
      cert=$(
        CA_KEY="$ca_key" cfssl gencert -loglevel 2 \
          -ca certs/ca/etcd.crt \
          -ca-key env:CA_KEY \
          -config /nix/store/...-signing-derived-h1-etcd-server.json \
          /nix/store/...-csr-derived-h1-etcd-server.json
      )
      mkdir --parents "$(dirname certs/derived/h1/etcd-server.crt)"
      ...
    ''
    ```

    :::
  */
  mkLeafScript =
    root: cert:
    let
      csrFile = builtins.toFile "csr-${cert.id}.json" (builtins.toJSON (mkCsr cert));
      signingConfigFile = builtins.toFile "signing-${cert.id}.json" (
        builtins.toJSON {
          signing.default = {
            inherit (cert) expiry usages;
          };
        }
      );
    in
    ''
      echo ${lib.escapeShellArg cert.id}
      ca_key=$(sops decrypt ${lib.escapeShellArg root.relativeSopsFile})
      cert=$(
        CA_KEY="$ca_key" cfssl gencert -loglevel 2 \
          -ca ${lib.escapeShellArg root.relativePath} \
          -ca-key env:CA_KEY \
          -config ${signingConfigFile} \
          ${csrFile}
      )
      ${mkWriteScript cert}
    '';
in
writeShellApplication {
  name = "recreate-certs";
  runtimeInputs = [
    cfssl
    git
    jq
    sops
  ];
  text =
    let
      cas = lib.pipe nixosConfigurations [
        lib.attrValues
        (lib.filter (host: host.options ? certToolkit))
        (lib.concatMap (host: lib.attrValues host.config.certToolkit.cas))
      ];

      rootScripts = lib.unique (map (ca: mkRootScript ca.root) cas);
      leafScripts = lib.concatMap (ca: map (mkLeafScript ca.root) (lib.attrValues ca.certs)) cas;
    in
    ''
      cd "$(git rev-parse --show-toplevel)"

      ${lib.concatLines rootScripts}
      ${lib.concatLines leafScripts}
    '';
}
