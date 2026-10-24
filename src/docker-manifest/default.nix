{
  lib,
  writers,
  writeShellScriptBin,
  docker-manifest,
}:
userModule:
let
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
  # Hidden and internal options, such as renamed ones, are not part of the interface.
  isInterface = opt: lib.isOption opt && opt.visible or true != false && !(opt.internal or false);
  configFile = writers.writeJSON "docker-manifest.json" (
    lib.filterAttrs (name: _: isInterface options.${name}) cfg
  );
in
writeShellScriptBin "docker-manifest" "exec ${lib.getExe docker-manifest} ${configFile}"
