# Evaluation coverage for configurations.
# `nix flake check` forces a configuration only as far as its toplevel derivation's
# attribute set, so an error reachable only from the builder script passes.
# Each target therefore becomes an empty file whose text forces the target's `drvPath`:
# evaluating the check forces the whole configuration, while building it never
# builds the configuration, and the file references nothing.
# Only the text depends on the target, so reading `system` or `meta` stays cheap.
# An empty `hydraPlatforms` keeps CI from building or pushing them (see `lib.isHydraTarget`).
{ lib, config, ... }:
let
  toplevel = cfg: cfg.config.system.build.toplevel;

  # Setting `system` explicitly avoids evaluating the configuration's pkgs to find it.
  fromConfigurations =
    class: package:
    lib.mapAttrs (_: cfg: {
      system = lib.mkDefault cfg.pkgs.stdenv.hostPlatform.system;
      package = lib.mkDefault (package cfg);
    }) (config.flake."${class}Configurations" or { });

  mkCheck =
    pkgs: name: target:
    lib.nameValuePair name (
      pkgs.writeTextFile {
        name = lib.strings.sanitizeDerivationName name;
        text = lib.seq target.package.drvPath "";
        meta.hydraPlatforms = [ ];
      }
    );
in
{
  options.evalTargets = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.lazyAttrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to evaluate the target as a check.";
            };
            system = lib.mkOption {
              # not restricted to `systems`, so configurations of other systems are merely not checked
              type = lib.types.str;
              description = "The system whose checks contain the target.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              description = "The derivation to evaluate.";
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Derivations evaluated as checks `eval-<class>-<name>` for their system, keyed by class and name.
      The configurations in `nixosConfigurations`, `darwinConfigurations`, and `homeConfigurations` are added by default.
    '';
  };

  config = {
    evalTargets = {
      nixos = fromConfigurations "nixos" toplevel;
      darwin = fromConfigurations "darwin" toplevel;
      home = fromConfigurations "home" (cfg: cfg.activationPackage);
    };

    perSystem =
      { system, pkgs, ... }:
      {
        checks = lib.concatMapAttrs (
          class: targets:
          lib.mapAttrs' (name: mkCheck pkgs "eval-${class}-${name}") (
            lib.filterAttrs (_: target: target.enable && target.system == system) targets
          )
        ) config.evalTargets;
      };
  };
}
