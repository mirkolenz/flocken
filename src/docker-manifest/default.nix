{
  lib,
  writers,
  writeShellScriptBin,
  docker-manifest,
}:
userModule:
let
  inherit (import ./interface.nix lib) toInterface;
  inherit
    (lib.evalModules {
      modules = [
        ./module.nix
        userModule
      ];
    })
    config
    options
    ;
  cfg = lib.showWarnings config.warnings config;
  configFile = writers.writeJSON "docker-manifest.json" (toInterface options cfg);
in
writeShellScriptBin "docker-manifest" "exec ${lib.getExe docker-manifest} ${configFile}"
