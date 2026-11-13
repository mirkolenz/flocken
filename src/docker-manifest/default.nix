{
  lib,
  writers,
  writeShellScript,
  writeShellScriptBin,
  python3Minimal,
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
  # The stream script of `dockerTools.streamLayeredImage` only needs the standard library,
  # so the host's interpreter runs it for images of every platform.
  nativeImage =
    image:
    if image ? streamScript && image ? conf then
      writeShellScript "${image.name}-native" "exec ${python3Minimal.interpreter} ${image.streamScript} ${image.conf}"
    else
      image;
  images = map (entry: entry // { image = nativeImage entry.image; }) cfg.images;
  configFile = writers.writeJSON "docker-manifest.json" (
    toInterface options (cfg // { inherit images; })
  );
in
writeShellScriptBin "docker-manifest" "exec ${lib.getExe docker-manifest} ${configFile}"
