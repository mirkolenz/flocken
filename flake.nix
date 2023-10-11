{
  description = "Flocken (German for 'flakes') is a collection of utilities for nix flakes.";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };
  outputs = inputs @ {
    self,
    flake-parts,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      perSystem = {
        pkgs,
        self',
        lib,
        ...
      }: {
        formatter = pkgs.alejandra;
        legacyPackages = {
          mkDockerManifest = pkgs.callPackage ./src/docker-manifest.nix;
        };
        apps = {
          checkDockerManifest = {
            type = "app";
            program = lib.getExe (self'.legacyPackages.mkDockerManifest {
              branch = "main";
              name = "ghcr.io/mirkolenz/flocken";
              version = "1.0.0";
              images = with self.packages; [x86_64-linux.dummyDocker];
              annotations.org.opencontainers.image = {
                source = "https://github.com/mirkolenz/flocken";
                description = "Flocken (German for 'flakes') is a collection of utilities for nix flakes.";
                licenses = "MIT";
              };
            });
          };
        };
        packages = {
          dummyDocker = pkgs.dockerTools.buildImage {
            name = "dummy";
          };
        };
      };
    };
}
