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
        packages = {
          testDockerManifest = self'.legacyPackages.mkDockerManifest {
            github = {
              enable = true;
              repo = "mirkolenz/flocken";
              actor = "mirkolenz";
              token = "";
            };
            branch = "main";
            version = "1.0.0";
            images = with self.packages; [x86_64-linux.dummyDocker];
          };
          dummyDocker = pkgs.dockerTools.buildImage {
            name = "dummy";
          };
        };
      };
    };
}
