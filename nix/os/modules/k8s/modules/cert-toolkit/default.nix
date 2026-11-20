{
  config,
  lib,
  inputsSinan,
  ...
}:
let
  cfg = config.certToolkit;

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
    flakeFile "nix/os/modules/k8s/certs/ca/etcd.crt"
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
    key = lib.mkOption { type = keyType; };
    expiry = lib.mkOption {
      type = lib.types.str;
      example = "876000h";
    };
    usages = lib.mkOption usagesOption;
    names = lib.mkOption { type = namesType; };
    commonName = lib.mkOption {
      type = lib.types.str;
      description = "Common Name";
    };
    hosts = lib.mkOption hostsOption;
    path = lib.mkOption {
      type = lib.types.path;
      description = "The store path of the certificate";
    };
    keyPath = lib.mkOption {
      type = lib.types.str;
      description = "The path of the decrypted key on the host";
    };
    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "The store path of the sops encrypted key";
    };
    relativePath = lib.mkOption {
      type = lib.types.str;
      description = "The path of the certificate relative to the flake root";
    };
    relativeSopsFile = lib.mkOption {
      type = lib.types.str;
      description = "The path of the sops encrypted key relative to the flake root";
    };
    id = lib.mkOption {
      type = lib.types.str;
      description = "A unique id to identify the cert";
    };
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
    usages = lib.mkOption usagesOption;
  };

  /**
    Definitions that pass defaults down to a cert, CA or a more specific
    defaults set. Each level uses a lower priority than the one below it,
    so the most specific definition wins and anything set directly wins
    over all defaults.

    # Inputs

    `priority`

    : Override priority of the definitions, higher is weaker

    `base`

    : Evaluated defaults to pass down

    # Type

    ```
    mkDerivedConfig :: Int -> AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `mkDerivedConfig` usage example

    ```nix
    mkDerivedConfig 1009 {
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
    priority: base:
    let
      fromBase = name: lib.mkIf (base.${name} != null) (lib.mkOverride priority base.${name});
    in
    lib.genAttrs [
      "expiry"
      "key"
      "hosts"
      "usages"
    ] fromBase
    // {
      sops = lib.mapAttrs (_: lib.mkOverride priority) base.sops;
      names = lib.mapAttrs (_: lib.mkOverride priority) base.names;
    };

  /**
    Declare a defaults option that inherits from another defaults set.

    # Inputs

    `priority`

    : Override priority of the inherited definitions

    `base`

    : Evaluated defaults to inherit from

    # Type

    ```
    mkDerivedDefaults :: Int -> AttrSet -> Option
    ```

    # Examples
    :::{.example}
    ## `mkDerivedDefaults` usage example

    ```nix
    # options
    certToolkit.caDefaults = mkDerivedDefaults 1009 config.certToolkit.defaults;

    # config
    certToolkit.defaults.expiry = "42h";

    config.certToolkit.caDefaults.expiry
    => "42h"
    ```

    :::
  */
  mkDerivedDefaults =
    priority: base:
    lib.mkOption {
      type = lib.types.submodule {
        options = defaultsOptions;
        config = mkDerivedConfig priority base;
      };
      default = { };
    };

  /**
    Type of `certToolkit.cas.<ca>.certs.<name>`, a leaf cert of this host
    signed by the root cert of its CA. Its key is deployed to the host
    with sops-nix.

    # Inputs

    `caName`

    : Name of the CA, the `<ca>` in the option path

    `ca`

    : Evaluated `certToolkit.cas.<ca>`, for its cert defaults

    # Type

    ```
    leafCertType :: String -> AttrSet -> OptionType
    ```

    # Examples
    :::{.example}
    ## `leafCertType` usage example

    ```nix
    # in the type of certToolkit.cas.etcd
    certs = lib.mkOption {
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
        options = certOptions;
        config = lib.mkMerge [
          (mkDerivedConfig 1007 ca.certDefaults)
          {
            names = lib.mkDefault { };
            id = "derived-${hostName}-${caName}-${name}";
            relativePath = "${cfg.dir}/derived/${hostName}/${caName}-${name}.crt";
            relativeSopsFile = "${cfg.dir}/derived/${hostName}/${caName}-${name}.key.sops";
            path = flakeFile config.relativePath;
            sopsFile = flakeFile config.relativeSopsFile;
            keyPath = secrets."certtoolkit-${config.id}".path;
          }
        ];
      }
    );

  /**
    Type of `certToolkit.cas.<ca>.root`, the self signed root cert of a CA.
    Its key stays in the repo and is never deployed to a host.

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
    # in the type of certToolkit.cas.etcd
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
          (mkDerivedConfig 1007 cfg.caDefaults)
          {
            names = lib.mkDefault { };
            hosts = lib.mkDefault [ ];
            id = "ca-${caName}";
            relativePath = "${cfg.dir}/ca/${caName}.crt";
            relativeSopsFile = "${cfg.dir}/ca/${caName}.key.sops";
            path = flakeFile config.relativePath;
          }
        ];
      }
    );

  /**
    Type of `certToolkit.cas.<ca>`, a CA: its root cert (`root`), the leaf
    certs it signs for this host (`certs`) and defaults for those certs
    (`certDefaults`).
  */
  caType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        certDefaults = mkDerivedDefaults 1008 cfg.certDefaults;
        root = lib.mkOption { type = rootCertType name; };
        certs = lib.mkOption {
          type = lib.types.attrsOf (leafCertType name config);
          default = { };
        };
      };
    }
  );
in
{
  options.certToolkit = {
    dir = lib.mkOption {
      type = lib.types.str;
      description = "Directory of the certs relative to the flake root";
      example = "nix/os/modules/k8s/certs";
    };
    defaults = lib.mkOption {
      type = lib.types.submodule { options = defaultsOptions; };
      default = { };
    };
    caDefaults = mkDerivedDefaults 1009 cfg.defaults;
    certDefaults = mkDerivedDefaults 1009 cfg.defaults;
    cas = lib.mkOption {
      type = lib.types.attrsOf caType;
      default = { };
    };
  };

  config.sops.secrets = lib.pipe cfg.cas [
    lib.attrValues
    (lib.concatMap (ca: lib.attrValues ca.certs))
    (map (cert: {
      name = "certtoolkit-${cert.id}";
      value = cert.sops // {
        inherit (cert) sopsFile;
        format = "binary";
      };
    }))
    lib.listToAttrs
  ];
}
