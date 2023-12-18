{
  description = "Flocken (German for 'flakes') is a collection of utilities for nix flakes.";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    systems,
    ...
  }: let
    lib = nixpkgs.lib.extend self.overlays.lib;
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      flake = {
        lib = import ./lib nixpkgs.lib;
        overlays = {
          lib = final: prev: {
            flocken = import ./lib prev;
          };
        };
      };
      perSystem = {
        pkgs,
        self',
        ...
      }: {
        formatter = pkgs.alejandra;
        legacyPackages = {
          mkDockerManifest = pkgs.callPackage ./src/docker-manifest.nix {
            inherit lib;
          };
        };
        packages = {
          test = pkgs.buildEnv {
            name = "test";
            paths = with self'.packages; [
              testDockerManifest
            ];
          };
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
