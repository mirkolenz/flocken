{
  inputs,
  self,
  ...
}:
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
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;
      legacyPackages = {
        mkDockerManifest = pkgs.callPackage ../src/docker-manifest {
          lib' = self.lib;
        };
      };
    };
}
