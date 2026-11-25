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
  inherit (import ./lib.nix { inherit lib; })
    mkRootCsrFile
    mkLeafCsrFile
    mkSigningConfigFile
    ;

  /**
    Shell to save the JSON that `cfssl gencert` printed into
    `$cfssl_json`: encrypt its private key with sops and write its
    certificate next to it. Recipients come from the `.sops.yaml`
    creation rule matching `relativeSopsKeyPath`.

    # Inputs

    `cert`

    : Evaluated root or leaf cert options

    # Type

    ```
    mkWriteScript :: AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `mkWriteScript` usage example

    ```nix
    mkWriteScript {
      relativeCertPath = "certs/leaf/h1/etcd-server.crt";
      relativeSopsKeyPath = "certs/leaf/h1/etcd-server.key.sops";
    }
    => ''
      mkdir --parents "$(dirname certs/leaf/h1/etcd-server.crt)"
      printf '%s' "$cfssl_json" \
        | jq --raw-output .key \
        | sops encrypt --filename-override certs/leaf/h1/etcd-server.key.sops --output certs/leaf/h1/etcd-server.key.sops /dev/stdin
      printf '%s' "$cfssl_json" | jq --raw-output .cert > certs/leaf/h1/etcd-server.crt
    ''
    ```

    :::
  */
  mkWriteScript =
    cert:
    let
      sopsFile = lib.escapeShellArg cert.relativeSopsKeyPath;
      certFile = lib.escapeShellArg cert.relativeCertPath;
    in
    ''
      mkdir --parents "$(dirname ${certFile})"
      printf '%s' "$cfssl_json" \
        | jq --raw-output .key \
        | sops encrypt --filename-override ${sopsFile} --output ${sopsFile} /dev/stdin
      printf '%s' "$cfssl_json" | jq --raw-output .cert > ${certFile}
    '';

  /**
    Shell to create the root cert of a CA. An existing root is kept, only
    the recipients of its key are synced with `.sops.yaml`.

    # Inputs

    `root`

    : Evaluated `sinan.certToolkit.cas.<ca>.root`

    # Type

    ```
    mkRootScript :: AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `mkRootScript` usage example

    ```nix
    mkRootScript config.sinan.certToolkit.cas.etcd.root
    => ''
      echo root-etcd
      if [ -e certs/root/etcd.key.sops ]; then
        sops updatekeys --yes certs/root/etcd.key.sops
      else
        cfssl_json=$(cfssl gencert -loglevel 2 -initca /nix/store/...-csr-root-etcd.json)
        mkdir --parents "$(dirname certs/root/etcd.crt)"
        ...
      fi
    ''
    ```

    :::
  */
  mkRootScript =
    root:
    let
      sopsFile = lib.escapeShellArg root.relativeSopsKeyPath;
    in
    ''
      echo ${lib.escapeShellArg root.id}
      if [ -e ${sopsFile} ]; then
        sops updatekeys --yes ${sopsFile}
      else
        cfssl_json=$(cfssl gencert -loglevel 2 -initca ${mkRootCsrFile root})
        ${mkWriteScript root}
      fi
    '';

  /**
    Shell to create a leaf cert signed by the root cert of its CA. The
    decrypted root key is handed to cfssl through the environment, so it
    never touches the disk.

    # Inputs

    `root`

    : Evaluated `sinan.certToolkit.cas.<ca>.root` to sign with

    `leaf`

    : Evaluated `sinan.certToolkit.cas.<ca>.leaves.<name>`

    # Type

    ```
    mkLeafScript :: AttrSet -> AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `mkLeafScript` usage example

    ```nix
    mkLeafScript config.sinan.certToolkit.cas.etcd.root config.sinan.certToolkit.cas.etcd.leaves.server
    => ''
      echo leaf-h1-etcd-server
      ca_key=$(sops decrypt certs/root/etcd.key.sops)
      cfssl_json=$(
        CA_KEY="$ca_key" cfssl gencert -loglevel 2 \
          -ca certs/root/etcd.crt \
          -ca-key env:CA_KEY \
          -config /nix/store/...-signing-leaf-h1-etcd-server.json \
          /nix/store/...-csr-leaf-h1-etcd-server.json
      )
      mkdir --parents "$(dirname certs/leaf/h1/etcd-server.crt)"
      ...
    ''
    ```

    :::
  */
  mkLeafScript = root: leaf: ''
    echo ${lib.escapeShellArg leaf.id}
    ca_key=$(sops decrypt ${lib.escapeShellArg root.relativeSopsKeyPath})
    cfssl_json=$(
      CA_KEY="$ca_key" cfssl gencert -loglevel 2 \
        -ca ${lib.escapeShellArg root.relativeCertPath} \
        -ca-key env:CA_KEY \
        -config ${mkSigningConfigFile leaf} \
        ${mkLeafCsrFile leaf}
    )
    ${mkWriteScript leaf}
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
        (lib.filter (host: host.options ? sinan.certToolkit))
        (lib.concatMap (host: lib.attrValues host.config.sinan.certToolkit.cas))
      ];

      rootScripts = lib.unique (map (ca: mkRootScript ca.root) cas);
      # NOTE: a shared leaf shows up once per host, listToAttrs
      # keeps the first one of each id so it is only created once
      leafScripts = lib.pipe cas [
        (lib.concatMap (
          ca:
          map (leaf: {
            name = leaf.id;
            value = mkLeafScript ca.root leaf;
          }) (lib.attrValues ca.leaves)
        ))
        lib.listToAttrs
        lib.attrValues
      ];
    in
    ''
      cd "$(git rev-parse --show-toplevel)"

      ${lib.concatLines rootScripts}
      ${lib.concatLines leafScripts}
    '';
}
