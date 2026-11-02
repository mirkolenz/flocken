{ inputs, ... }:
let
  lib' = import ../lib inputs.nixpkgs.lib;
in
{
  imports = lib'.getModules ./.;
  flake = {
    lib = lib';
    overlays = {
      lib = final: prev: {
        flocken = import ../lib prev;
      };
    };
  };
  perSystem =
    { pkgs, config, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;
      packages = {
        docker-manifest = pkgs.callPackage ../src/docker-manifest/package.nix { };
      };
      legacyPackages = {
        mkDarwinApp = pkgs.callPackage ../src/darwin-app.nix { };
        mkGitHubBinary = pkgs.callPackage ../src/github-binary.nix { };
        mkDockerManifest = pkgs.callPackage ../src/docker-manifest {
          inherit (config.packages) docker-manifest;
        };
      };
    };
}
