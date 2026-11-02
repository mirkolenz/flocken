# Declares `flake.lib` as a lazy attribute set, so several modules can add helpers to it.
{ lib, flake-parts-lib, ... }:
{
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Helper functions of the flake.";
    };
  };
}
