# Compares the types of the options with those of the script in both directions,
# so drift between both fails the check.
{
  lib,
  runCommand,
  writers,
  jq,
  docker-manifest,
}:
let
  inherit (import ./interface.nix lib) interfaceOptions toSchema;
  inherit (lib.evalModules { modules = [ ./module.nix ]; }) options;
  schema = writers.writeJSON "options-schema.json" {
    object = lib.mapAttrs (_: opt: toSchema opt.type) (interfaceOptions options);
  };
in
runCommand "docker-manifest-schema" { nativeBuildInputs = [ jq ]; } ''
  diff --unified --label options --label script \
    <(jq --sort-keys . ${schema}) \
    <(${lib.getExe docker-manifest} --schema | jq --sort-keys .)
  touch $out
''
