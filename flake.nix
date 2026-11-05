{
  description = "Flocken (German for 'flakes') is a collection of utilities for nix flakes.";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };
  outputs =
    inputs@{
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      imports = [
        flake-parts.flakeModules.partitions
        ./modules
      ];
      partitionedAttrs = {
        checks = "dev";
        formatter = "dev";
        packages = "dev";
      };
      partitions.dev.module = ./dev;
    };
}
