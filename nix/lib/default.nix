{
  pkgs,
  nix-kube-generators,
}:
let
  inherit (pkgs) lib;
  kubelib = nix-kube-generators.lib { inherit pkgs; };
in
{
  # NOTE: this function links /share, doc, etc... from raw pkgs, so
  # bash-completion, Desktop entries, etc... can be reused
  nixpakEnv =
    {
      pkg_raw,
      pkg_nixpak,
    }:
    pkgs.buildEnv {
      inherit (pkg_raw)
        pname
        version
        meta
        ;
      paths = [
        (pkgs.buildEnv {
          name = "${pkg_raw.pname}-share";
          paths = [
            pkg_raw
          ];
          pathsToLink = [
            "/share"
          ];
          extraOutputsToInstall = [
            "man"
            "doc"
          ];
        })
        pkg_nixpak
      ];
      pathsToLink = [
        "/share"
        "/bin"
      ];
      extraOutputsToInstall = [
        "man"
        "doc"
      ];
    };

  # NOTE: a nixpak script is a `#!launcher` script, so the process is named
  # "launcher" and that is what tmux and ps show. The kernel names a process
  # after the file it was exec'd as, so run the launcher through a symlink
  nixpakNamed =
    {
      nixpak,
      pkg_raw,
    }:
    let
      name = pkg_raw.meta.mainProgram or pkg_raw.name;
      launcher = pkgs.callPackage "${nixpak}/launcher" { };
    in
    "${
      pkgs.runCommandLocal "nixpak-named-${name}" { } ''
        mkdir -p $out/bin
        ln -s ${launcher}/bin/launcher $out/bin/${name}
      ''
    }/bin/${name}";

  # NOTE: bwrap --new-session leaves the sandbox without a
  # controlling terminal, so the kernel never delivers SIGWINCH to it and
  # TUIs keep their startup size. This leaves a sidecar in the foreground
  # process group that relays SIGWINCH from the host side to the sessions
  nixpakWinch =
    let
      # NOTE: a separate script, so runtimeInputs does not leak
      # into the PATH of the launcher and from there into the sandbox
      sidecar = pkgs.writeShellApplication {
        name = "nixpak-winch-sidecar";
        runtimeInputs = with pkgs; [
          coreutils
          procps
        ];
        text = ''
          launcher="$1"
          sid="$(ps -o sid= -p "$$")"
          sid="$((sid))"

          # NOTE: walk down from the launcher while still in our
          # session, the first process in another session is the sandbox,
          # signal that session and do not descend into it
          forward() {
            ps -o pid=,sid= --ppid "$1" | while read -r pid psid; do
              if [ "$psid" = "$sid" ]; then
                forward "$pid"
              else
                pkill -WINCH -s "$psid" || :
              fi
            done || :
          }
          trap 'forward "$launcher"' WINCH

          # NOTE: returns when the launcher is gone, a trapped
          # SIGWINCH interrupts the wait, so go back to waiting
          tail --pid="$launcher" -f /dev/null &
          while kill -0 "$!" 2>/dev/null; do
            wait "$!" || :
          done
        '';
      };
    in
    pkgs.writeShellScript "nixpak-winch" ''
      [ -t 0 ] || [ -t 1 ] || [ -t 2 ] || exec "$@"

      # NOTE: $$ becomes the launcher once it is exec'd. No tty or
      # pipe fds are kept, so readers of our stdout still see EOF when the
      # launcher exits. The launcher reaps every child before it exits, so
      # the sidecar is forked twice to not be one, else both would wait on
      # each other forever
      (${lib.getExe sidecar} "$$" </dev/null >/dev/null 2>&1 &)

      exec "$@"
    '';

  /**
    An https URL to a host and port, with the brackets an IPv6 address needs.

    # Inputs

    `host`

    : Host name or address

    `port`

    : Port

    # Type

    ```
    hostToUrl :: String -> Int -> String
    ```

    # Examples
    :::{.example}
    ## `hostToUrl` usage example

    ```nix
    hostToUrl "master1" 2379
    => "https://master1:2379"
    hostToUrl "2001:db8::1" 2380
    => "https://[2001:db8::1]:2380"
    ```

    :::
  */
  hostToUrl =
    host: port: "https://${if lib.hasInfix ":" host then "[${host}]" else host}:${toString port}";

  /**
    The host of a URL, without scheme, port, path or the brackets of an IPv6
    address.

    # Inputs

    `url`

    : A URL like "https://master1:2379" or "https://[2001:db8::1]:2380"

    # Type

    ```
    urlToHost :: String -> String
    ```

    # Examples
    :::{.example}
    ## `urlToHost` usage example

    ```nix
    urlToHost "https://master1:2379"
    => "master1"
    urlToHost "https://[2001:db8::1]:2380"
    => "2001:db8::1"
    ```

    :::
  */
  urlToHost =
    url:
    let
      authority = lib.head (lib.splitString "/" (lib.last (lib.splitString "://" url)));
    in
    if lib.hasPrefix "[" authority then
      lib.head (lib.splitString "]" (lib.removePrefix "[" authority))
    else
      lib.head (lib.splitString ":" authority);

  /**
    Pull an OCI image pinned by digest, for the architecture of the host
    it is built for. Meant for `services.kubernetes.kubelet.seedDockerImages`,
    so nodes never pull it and VM tests work offline.

    # Inputs

    `args`

    : An attribute set containing:

      `name`

      : Full image name, like `ghcr.io/kube-vip/kube-vip`

      `tag`

      : Image tag, the pods refer to the image by it

      `digest`

      : Digest of the multi architecture image index

      `hashes`

      : Hash of the pulled image per go architecture (`amd64`, `arm64`)

    # Type

    ```
    ociImagePull :: { name :: String; tag :: String; digest :: String; hashes :: { [String] :: String }; } -> Derivation
    ```

    # Examples
    :::{.example}
    ## `ociImagePull` usage example

    ```nix
    ociImagePull {
      name = "ghcr.io/kube-vip/kube-vip";
      tag = "v1.2.4";
      digest = "sha256:dde4...";
      hashes = {
        amd64 = "sha256-THDo...";
        arm64 = "sha256-/Ywp...";
      };
    }
    ```

    :::
  */
  ociImagePull =
    {
      name,
      tag,
      digest,
      hashes,
    }:
    pkgs.dockerTools.pullImage {
      imageName = name;
      imageDigest = digest;
      hash = hashes.${pkgs.go.GOARCH};
      finalImageName = name;
      finalImageTag = tag;
      os = "linux";
      arch = pkgs.go.GOARCH;
    };

  /**
    The `image` values of a Helm chart for an image pulled with
    `ociImagePull`, by tag, so the pods run exactly the seeded image.

    # Inputs

    `image`

    : Image derivation from `ociImagePull`

    # Type

    ```
    ociImageValues :: Derivation -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `ociImageValues` usage example

    ```nix
    ociImageValues kubeVipImage
    => {
      repository = "ghcr.io/kube-vip/kube-vip";
      tag = "v1.2.4";
      pullPolicy = "IfNotPresent";
    }
    ```

    :::
  */
  ociImageValues = image: {
    repository = image.imageName;
    tag = image.imageTag;
    pullPolicy = "IfNotPresent";
  };

  /**
    Render a Helm chart and key its resources by chart, kind and name, the
    shape `services.kubernetes.addonManager.bootstrapAddons` takes. The
    chart is rendered while evaluating (import from derivation).

    # Inputs

    `helmArgs`

    : Arguments of `kubelib.buildHelmChart`

    # Type

    ```
    mkChartAddons :: AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `mkChartAddons` usage example

    ```nix
    mkChartAddons { name = "kube-vip"; chart = ...; values = ...; }
    => {
      kube-vip-daemonset-kube-vip = { kind = "DaemonSet"; ... };
      kube-vip-clusterrole-kube-vip = { kind = "ClusterRole"; ... };
      ...
    }
    ```

    :::
  */
  mkChartAddons =
    helmArgs:
    lib.pipe helmArgs [
      kubelib.fromHelm
      (map (resource: {
        name = lib.toLower "${helmArgs.name}-${resource.kind}-${resource.metadata.name}";
        value = resource;
      }))
      lib.listToAttrs
    ];

  /**
    Build the `recreate-certs` script, which creates the root and leaf
    certs every host declares with `sinan.certToolkit` and encrypts their
    keys with sops. It runs from the top of the git repo it is started in
    and takes the recipients from the `.sops.yaml` there, so another flake
    importing `nixosModules.k8s` can create its certs in its own repo.

    # Inputs

    `args`

    : An attribute set containing:

      `nixosConfigurations`

      : NixOS systems to collect the certs from, systems without the cert
        toolkit are skipped

    # Type

    ```
    mkCertsRecreate :: { nixosConfigurations :: { [String] :: AttrSet }; } -> Derivation
    ```

    # Examples
    :::{.example}
    ## `mkCertsRecreate` usage example

    ```nix
    # in the outputs of another flake
    apps.x86_64-linux.certs-recreate = {
      type = "app";
      program = lib.getExe (
        (sinan.lib { inherit pkgs; }).mkCertsRecreate {
          inherit (self) nixosConfigurations;
        }
      );
    };
    ```

    :::
  */
  mkCertsRecreate =
    { nixosConfigurations }:
    pkgs.callPackage ../os/modules/k8s/modules/cert-toolkit/recreate.nix {
      inherit nixosConfigurations;
    };
}
