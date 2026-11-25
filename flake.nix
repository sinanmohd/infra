{
  description = "sinan's reproducible systems";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    nix-kube-generators.url = "github:farcaller/nix-kube-generators";

    bootvine = {
      url = "git+https://codeberg.org/wvhulle/bootvine";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrap = {
      url = "github:rti/nixwrap";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    website = {
      url = "github:sinanmohd/website";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:sinanmohd/home-manager/sway-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      home-manager,
      deploy-rs,
      lanzaboote,
      nix-index-database,
      disko,
      website,
      wrap,
      nixpak,
      bootvine,
      nix-kube-generators,
    }@inputs:
    let
      lib = nixpkgs.lib;

      inputsModule = {
        key = "inputs.infra.sinanmohd.com";
        _module.args.inputsSinan = inputs;
      };

      nixosImports = [
        inputsModule
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        nix-index-database.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        disko.nixosModules.disko
        bootvine.nixosModules.default
      ];

      makeNixosModules = moduleName: {
        imports = nixosImports ++ [
          ./nix/os/modules/${moduleName}
        ];
      };
      makeNixosConfigs =
        host: system:
        lib.nixosSystem {
          inherit system;
          modules = nixosImports ++ [
            ./nix/os/hosts/${host}
          ];
        };

      makeHomeModules = moduleName: {
        imports = [
          inputsModule
          ./nix/home/modules/${moduleName}
        ];
      };
      makeHomeConfigs =
        host: system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            inputsModule
            ./nix/home/hosts/${host}
          ];
        };

      forSystem =
        f: system:
        f {
          inherit system;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (lib.getName pkg) [
                "claude-code"
                "antigravity-cli"
              ];
          };
        };
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs supportedSystems (forSystem f);
    in
    {
      lib = { pkgs }: import ./nix/lib { inherit pkgs nix-kube-generators; };

      packages = forAllSystems (
        { system, pkgs }:
        {
          wayland-scripts = pkgs.callPackage ./nix/pkgs/com.sinanmohd.wayland-scripts {
            alacritty = pkgs.alacritty-graphics;
          };
          claude-code = pkgs.callPackage ./nix/pkgs/com.anthropic.claude-code.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          opencode = pkgs.callPackage ./nix/pkgs/ly.anoma.opencode.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          antigravity-cli = pkgs.callPackage ./nix/pkgs/com.google.antigravity-cli.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          git = pkgs.callPackage ./nix/pkgs/com.git-scm.git.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          firefox = pkgs.callPackage ./nix/pkgs/org.mozilla.firefox.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          element-desktop = pkgs.callPackage ./nix/pkgs/im.riot.Riot {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          chromium = pkgs.callPackage ./nix/pkgs/org.chromium.Chromium.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          qbittorrent = pkgs.callPackage ./nix/pkgs/org.qbittorrent.qBittorrent.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          neovim = pkgs.callPackage ./nix/pkgs/io.neovim.nvim.nix {
            inherit nixpak;
            libSinan = self.lib { inherit pkgs; };
          };
          nvim-sinan = pkgs.callPackage ./nix/pkgs/com.sinanmohd.nvim {
            neovim = self.packages.${system}.neovim;
          };
        }
      );

      apps = forAllSystems (
        { pkgs, ... }:
        {
          certs-recreate = {
            type = "app";
            meta.description = "Create the root and leaf certs declared with sinan.certToolkit";
            program = lib.getExe (
              pkgs.callPackage ./nix/os/modules/k8s/modules/cert-toolkit/recreate.nix {
                inherit (self) nixosConfigurations;
              }
            );
          };
        }
      );

      nixosModules = lib.genAttrs [
        "common"
        "server"
        "pc"
        "wayland"
        "network"
        "k8s"
      ] makeNixosModules;
      nixosConfigurations = lib.genAttrs [
        "cez"
        "kay"
      ] (host: makeNixosConfigs host "x86_64-linux");

      homeModules = lib.genAttrs [
        "common"
        "wayland"
        "pc"
      ] makeHomeModules;
      homeConfigurations = lib.genAttrs [
        "cez"
      ] (host: makeHomeConfigs host "x86_64-linux");

      deploy = {
        sshUser = "sinan";
        user = "root";
        remoteBuild = true;
        nodes.kay = {
          hostname = "kay";
          profilesOrder = [ "system" ];
          profiles.system = {
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.kay;
          };
        };
      };

      checks = forAllSystems (
        { system, pkgs }:
        {
          cert-toolkit = pkgs.callPackage ./nix/os/tests/cert-toolkit.nix { inherit self; };
          k8s = pkgs.callPackage ./nix/os/tests/k8s.nix { inherit self; };
        }
        // (deploy-rs.lib.${system}.deployChecks self.deploy)
        // (lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
          import ./nix/os/tests/vm-k8s.nix {
            inherit lib self;
            inherit (pkgs) testers;
          }
        ))
      );
    };
}
