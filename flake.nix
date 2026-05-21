{
  description = "sinan's reproducible systems";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";

    sops-nix = {
      url = "github:Mic92/sops-nix";
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
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      home-manager,
      deploy-rs,
      nix-index-database,
    }:
    let
      lib = nixpkgs.lib;
      nixosImports = [
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        nix-index-database.nixosModules.default
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
          ./nix/home/modules/${moduleName}
        ];
      };
      makeHomeConfigs =
        host: system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ ./nix/home/hosts/${host} ];
        };
    in
    {
      nixosModules = lib.genAttrs [
        "common"
        "server"
        "pc"
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

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
