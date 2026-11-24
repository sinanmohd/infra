{
  config,
  lib,
  pkgs,
  inputsSinan,
  ...
}:
let
  cfg = config.sinan.certToolkit;
  mkDefaultPriority = (lib.mkDefault null).priority;

  inherit (import ./lib.nix { inherit lib; })
    mkRootCsrFile
    mkLeafCsrFile
    mkSigningConfigFile
    ;

  /**
    Copy a file of this flake into its own store path, so a host only
    pulls that file into its closure instead of the whole flake source.

    # Inputs

    `relative`

    : Path of the file relative to the flake root

    # Type

    ```
    flakeFile :: String -> String
    ```

    # Examples
    :::{.example}
    ## `flakeFile` usage example

    ```nix
    flakeFile "nix/os/modules/k8s/certs/root/etcd.crt"
    => "/nix/store/3lgfq21nci0l432g5g5xbh48j0i7xxqh-etcd.crt"
    ```

    :::
  */
  flakeFile =
    relative:
    builtins.path {
      path = "${inputsSinan.self.outPath}/${relative}";
    };

  keyType = lib.types.submodule {
    options = {
      algo = lib.mkOption {
        type = lib.types.enum [
          "ecdsa"
          "rsa"
        ];
      };
      size = lib.mkOption { type = lib.types.int; };
    };
  };

  namesType = lib.types.submodule {
    options =
      lib.mapAttrs
        (
          _: description:
          lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            inherit description;
          }
        )
        {
          C = "Country (2-letter ISO code)";
          ST = "State or Province";
          L = "Locality / City";
          O = "Organization";
          OU = "Organizational Unit";
        };
  };

  hostsOption = {
    type = lib.types.listOf lib.types.str;
    example = [ "example.com" ];
  };
  usagesOption = {
    type = lib.types.listOf lib.types.str;
    example = [ "signing" ];
  };
  sopsOptions = {
    sops = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Extra `sops.secrets.<name>` settings for the decrypted key, like
        its owner or the units to restart when it changes
      '';
      example = {
        owner = "etcd";
        restartUnits = [ "etcd.service" ];
      };
    };
  };

  certOptions = sopsOptions // {
    package = lib.mkOption {
      type = lib.types.package;
      description = ''
        The derivation creating the certificate and its key, only used
        with `sinan.certToolkit.createCerts`
      '';
    };
    key = lib.mkOption { type = keyType; };
    expiry = lib.mkOption {
      type = lib.types.str;
      example = "876000h";
    };
    names = lib.mkOption { type = namesType; };
    commonName = lib.mkOption {
      type = lib.types.str;
      description = "Common Name";
    };
    hosts = lib.mkOption hostsOption;
    certPath = lib.mkOption {
      type = lib.types.path;
      description = "The store path of the certificate";
    };
    keyPath = lib.mkOption {
      type = lib.types.str;
      description = "The path of the decrypted key on the host";
    };
    sopsKeyPath = lib.mkOption {
      type = lib.types.path;
      description = "The store path of the sops encrypted key";
    };
    relativeCertPath = lib.mkOption {
      type = lib.types.str;
      description = "The path of the certificate relative to the flake root";
    };
    relativeSopsKeyPath = lib.mkOption {
      type = lib.types.str;
      description = "The path of the sops encrypted key relative to the flake root";
    };
    id = lib.mkOption {
      type = lib.types.str;
      description = "A unique id to identify the root or leaf cert";
    };
  };

  # NOTE: only leaves take usages, cfssl hardcode root usage
  leafOptions = certOptions // {
    usages = lib.mkOption usagesOption;
  };

  defaultsOptions = sopsOptions // {
    key = lib.mkOption {
      type = lib.types.nullOr keyType;
      default = null;
    };
    expiry = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    names = lib.mkOption {
      type = namesType;
      default = { };
    };
    hosts = lib.mkOption hostsOption;
  };

  leafDefaultsOptions = defaultsOptions // {
    usages = lib.mkOption usagesOption;
  };

  /**
    Definitions that pass defaults down to a root or leaf cert, a CA or a
    more specific defaults set. Each level uses a lower priority than the
    one below it, so the most specific definition wins and anything set
    directly wins over all defaults.

    # Inputs

    `priority`

    : Override priority of the definitions, higher is weaker

    `options`

    : Options of the receiving set, only fields it declares are passed
      down

    `base`

    : Evaluated defaults to pass down

    # Type

    ```
    mkDerivedConfig :: Int -> AttrSet -> AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `mkDerivedConfig` usage example

    ```nix
    mkDerivedConfig (mkDefaultPriority + 9) leafDefaultsOptions {
      expiry = "42h";
      key = null;
      hosts = [ "h1" ];
      usages = [ "server auth" ];
      sops = { owner = "etcd"; };
      names = { C = "IN"; ST = null; L = null; O = null; OU = null; };
    }
    => {
      expiry = lib.mkIf true (lib.mkOverride 1009 "42h");
      key = lib.mkIf false (lib.mkOverride 1009 null);
      hosts = lib.mkIf true (lib.mkOverride 1009 [ "h1" ]);
      usages = lib.mkIf true (lib.mkOverride 1009 [ "server auth" ]);
      sops = { owner = lib.mkOverride 1009 "etcd"; };
      names = {
        C = lib.mkOverride 1009 "IN";
        ST = lib.mkOverride 1009 null;
        L = lib.mkOverride 1009 null;
        O = lib.mkOverride 1009 null;
        OU = lib.mkOverride 1009 null;
      };
    }
    ```

    :::
  */
  mkDerivedConfig =
    priority: options: base:
    let
      fromBase = name: lib.mkIf (base.${name} != null) (lib.mkOverride priority base.${name});
      fields = lib.filter (name: options ? ${name}) [
        "expiry"
        "key"
        "hosts"
        "usages"
      ];
    in
    lib.genAttrs fields fromBase
    // {
      sops = lib.mapAttrs (_: lib.mkOverride priority) base.sops;
      names = lib.mapAttrs (_: lib.mkOverride priority) base.names;
    };

  /**
    Declare a defaults option that inherits from another defaults set.

    # Inputs

    `priority`

    : Override priority of the inherited definitions

    `options`

    : Options of the new defaults set, `defaultsOptions` or
      `leafDefaultsOptions`

    `base`

    : Evaluated defaults to inherit from

    # Type

    ```
    mkDerivedDefaults :: Int -> AttrSet -> AttrSet -> Option
    ```

    # Examples
    :::{.example}
    ## `mkDerivedDefaults` usage example

    ```nix
    # options
    sinan.certToolkit.rootDefaults = mkDerivedDefaults (mkDefaultPriority + 9) defaultsOptions config.sinan.certToolkit.defaults;

    # config
    sinan.certToolkit.defaults.expiry = "42h";

    config.sinan.certToolkit.rootDefaults.expiry
    => "42h"
    ```

    :::
  */
  mkDerivedDefaults =
    priority: options: base:
    lib.mkOption {
      type = lib.types.submodule {
        inherit options;
        config = mkDerivedConfig priority options base;
      };
      default = { };
    };

  /**
    Type of `sinan.certToolkit.cas.<ca>.leaves.<name>`, a leaf cert of
    this host signed by the root cert of its CA. Its key is deployed to
    the host with sops-nix.

    # Inputs

    `caName`

    : Name of the CA, the `<ca>` in the option path

    `ca`

    : Evaluated `sinan.certToolkit.cas.<ca>`, for its `leafDefaults`

    # Type

    ```
    leafCertType :: String -> AttrSet -> OptionType
    ```

    # Examples
    :::{.example}
    ## `leafCertType` usage example

    ```nix
    # in the type of sinan.certToolkit.cas.etcd
    leaves = lib.mkOption {
      type = lib.types.attrsOf (leafCertType "etcd" config);
    };
    ```

    :::
  */
  leafCertType =
    let
      secrets = config.sops.secrets;
      hostName = config.networking.hostName;
    in
    caName: ca:
    lib.types.submodule (
      { name, config, ... }:
      {
        options = leafOptions;
        config = lib.mkMerge [
          (mkDerivedConfig (mkDefaultPriority + 7) leafOptions ca.leafDefaults)
          {
            names = lib.mkDefault { };
            id = "leaf-${hostName}-${caName}-${name}";
            relativeCertPath = "${cfg.dir}/leaf/${hostName}/${caName}-${name}.crt";
            relativeSopsKeyPath = "${cfg.dir}/leaf/${hostName}/${caName}-${name}.key.sops";
            package = lib.mkDefault (
              pkgs.runCommand "certtoolkit-${config.id}" { nativeBuildInputs = [ pkgs.cfssl ]; } ''
                cfssl gencert -loglevel 2 \
                  -ca ${ca.root.package}/ca.crt \
                  -ca-key ${ca.root.package}/ca.key \
                  -config ${mkSigningConfigFile config} \
                  ${mkLeafCsrFile config} \
                  | cfssljson -bare cert
                install -D --mode 444 cert.pem "$out/cert.crt"
                install -D --mode 444 cert-key.pem "$out/cert.key"
              ''
            );
            certPath =
              if cfg.createCerts then "${config.package}/cert.crt" else flakeFile config.relativeCertPath;
            sopsKeyPath = flakeFile config.relativeSopsKeyPath;
            keyPath =
              if cfg.createCerts then "${config.package}/cert.key" else secrets."certtoolkit-${config.id}".path;
          }
        ];
      }
    );

  /**
    Type of `sinan.certToolkit.cas.<ca>.root`, the self signed root cert
    of a CA. Its key stays in the repo and is never deployed to a host.

    # Inputs

    `caName`

    : Name of the CA, the `<ca>` in the option path

    # Type

    ```
    rootCertType :: String -> OptionType
    ```

    # Examples
    :::{.example}
    ## `rootCertType` usage example

    ```nix
    # in the type of sinan.certToolkit.cas.etcd
    root = lib.mkOption { type = rootCertType "etcd"; };
    ```

    :::
  */
  rootCertType =
    caName:
    lib.types.submodule (
      { config, ... }:
      {
        options = certOptions;
        config = lib.mkMerge [
          (mkDerivedConfig (mkDefaultPriority + 7) certOptions cfg.rootDefaults)
          {
            names = lib.mkDefault { };
            hosts = lib.mkDefault [ ];
            id = "root-${caName}";
            relativeCertPath = "${cfg.dir}/root/${caName}.crt";
            relativeSopsKeyPath = "${cfg.dir}/root/${caName}.key.sops";
            package = lib.mkDefault (
              pkgs.runCommand "certtoolkit-${config.id}" { nativeBuildInputs = [ pkgs.cfssl ]; } ''
                cfssl gencert -loglevel 2 -initca ${mkRootCsrFile config} \
                  | cfssljson -bare ca
                install -D --mode 444 ca.pem "$out/ca.crt"
                install -D --mode 444 ca-key.pem "$out/ca.key"
              ''
            );
            certPath =
              if cfg.createCerts then "${config.package}/ca.crt" else flakeFile config.relativeCertPath;
          }
        ];
      }
    );

  /**
    Type of `sinan.certToolkit.cas.<ca>`, a CA: its root cert (`root`), the
    leaf certs it signs for this host (`leaves`) and defaults for those
    leaf certs (`leafDefaults`).
  */
  caType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        leafDefaults = mkDerivedDefaults (mkDefaultPriority + 8) leafDefaultsOptions cfg.leafDefaults;
        root = lib.mkOption { type = rootCertType name; };
        leaves = lib.mkOption {
          type = lib.types.attrsOf (leafCertType name config);
          default = { };
        };
      };
      config = lib.mkIf (cfg.clusterFrom != null && cfg.clusterFrom.cas ? ${name}) {
        root.package = lib.mkOverride (mkDefaultPriority - 100) cfg.clusterFrom.cas.${name}.root.package;
      };
    }
  );
in
{
  options.sinan.certToolkit = {
    dir = lib.mkOption {
      type = lib.types.str;
      description = "Directory of the root and leaf certs relative to the flake root";
      example = "nix/os/modules/k8s/certs";
    };
    createCerts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to create the root and leaf certs and their keys in
        derivations instead of reading them from `dir`. The keys end up
        world readable in the nix store, so this is only meant for tests.
      '';
    };
    clusterFrom = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = ''
        The `config.sinan.certToolkit` of another host to take the root cert
        packages from, so hosts using `createCerts` share their CAs. It does
        nothing without `createCerts`, so like it, this is only meant for
        tests.
      '';
    };
    defaults = lib.mkOption {
      type = lib.types.submodule { options = leafDefaultsOptions; };
      default = { };
    };
    rootDefaults = mkDerivedDefaults (mkDefaultPriority + 9) defaultsOptions cfg.defaults;
    leafDefaults = mkDerivedDefaults (mkDefaultPriority + 9) leafDefaultsOptions cfg.defaults;
    cas = lib.mkOption {
      type = lib.types.attrsOf caType;
      default = { };
    };
  };

  config.sops.secrets = lib.mkIf (!cfg.createCerts) (
    lib.pipe cfg.cas [
      lib.attrValues
      (lib.concatMap (ca: lib.attrValues ca.leaves))
      (map (leaf: {
        name = "certtoolkit-${leaf.id}";
        value = leaf.sops // {
          sopsFile = leaf.sopsKeyPath;
          format = "binary";
        };
      }))
      lib.listToAttrs
    ]
  );
}
