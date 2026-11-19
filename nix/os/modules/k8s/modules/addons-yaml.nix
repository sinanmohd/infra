{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kubernetes.addonManager.addonsYaml;

  /**
    Split a multi document yaml into a json list of objects, empty
    documents (like a trailing `---`) are dropped.

    # Inputs

    `name`

    : Name of the derivation, `.json` is appended

    `src`

    : Path to the multi document yaml

    # Type

    ```
    toJsonList :: String -> Path -> Derivation
    ```
  */
  toJsonList =
    name: src:
    pkgs.runCommand "${name}.json" { } ''
      ${lib.getExe pkgs.yq-go} eval 'select(length > 0)' ${src} \
        | ${lib.getExe pkgs.yq-go} eval-all '[.]' --output-format json > $out
    '';

  /**
    Label an object so the addon manager reconciles it. The addon manager
    applies with a label selector, which kubectl matches against each item
    after flattening the list, so every item needs the label, not just the
    list.

    # Inputs

    `object`

    : Kubernetes object to label

    # Type

    ```
    reconcile :: AttrSet -> AttrSet
    ```
  */
  reconcile =
    object:
    lib.recursiveUpdate object {
      metadata.labels."addonmanager.kubernetes.io/mode" = "Reconcile";
    };
in
{
  options.services.kubernetes.addonManager.addonsYaml = lib.mkOption {
    description = ''
      Multi document yaml files (like the ones released by cert-manager)
      to deploy through the addon manager.
    '';
    example = lib.literalExpression ''
      {
        cert-manager =
          let
            version = "1.18.2";
          in
          pkgs.fetchurl {
            url = "https://github.com/cert-manager/cert-manager/releases/download/v''${version}/cert-manager.yaml";
            hash = "sha256-BUa2S8gGI3iFzMgONFvOFYXrLsL0dqevWT8DCr2zoW8=";
          };
      }
    '';
    type = lib.types.attrsOf lib.types.path;
    default = { };
  };

  # WARN: IFD, the split yaml is built at evaluation time
  config.services.kubernetes.addonManager.addons = lib.mapAttrs (name: src: {
    apiVersion = "v1";
    kind = "List";
    items = map reconcile (lib.importJSON (toJsonList name src));
  }) cfg;
}
