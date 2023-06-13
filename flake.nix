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
      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
        legacyPackages = {
          mkDockerManifest = pkgs.callPackage ./src/docker-manifest.nix;
        };
      };
    };
}
