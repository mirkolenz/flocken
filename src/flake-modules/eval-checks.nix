# Evaluation coverage for the nixos, darwin, and home configurations of the flake.
# `nix flake check` forces a configuration only as far as its toplevel derivation's
# attribute set, so an error reachable only from the builder script passes.
# Each configuration therefore becomes an empty file whose text forces its `drvPath`:
# evaluating the check forces the whole configuration, while building it never
# builds the configuration, and the file references nothing.
# `dontDistribute` keeps CI from building or pushing them (see `lib.isHydraTarget`).
{ lib, config, ... }:
let
  toplevel = cfg: cfg.config.system.build.toplevel;
  targets = {
    nixos = toplevel;
    darwin = toplevel;
    home = cfg: cfg.activationPackage;
  };
in
{
  perSystem =
    { system, pkgs, ... }:
    {
      checks = lib.concatMapAttrs (
        class: target:
        lib.concatMapAttrs (
          name: cfg:
          lib.optionalAttrs (cfg.pkgs.stdenv.hostPlatform.system == system) {
            "eval-${class}-${name}" = lib.dontDistribute (
              pkgs.writeTextFile {
                name = lib.strings.sanitizeDerivationName "eval-${class}-${name}";
                text = lib.seq (target cfg).drvPath "";
              }
            );
          }
        ) (config.flake."${class}Configurations" or { })
      ) targets;
    };
}
