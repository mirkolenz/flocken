{
  lib,
  writeShellScriptBin,
  buildah,
  images,
  name ? "",
  names ? [],
  branch ? "",
  latest ? (builtins.elem branch ["main" "master"]),
  version ? "",
  sourceProtocol ? "docker-archive:",
  targetProtocol ? "docker://",
  format ? "oci",
  extraTags ? [],
  annotations ? {},
  ...
}: let
  version = lib.removePrefix "v" version;
  manifestName = "flocken";
  names = names ++ (lib.optional (name != "") name);
  tags =
    extraTags
    ++ (lib.optional (branch != "") branch)
    ++ (lib.optional latest "latest")
    ++ (lib.optional (version != "") version)
    ++ (lib.optionals (version != "" && !lib.hasInfix "-" version) [
      (lib.versions.majorMinor version)
      (lib.versions.major version)
    ]);
in
  assert (lib.assertMsg (builtins.length names > 0) "At least one name must be specified");
  assert (lib.assertMsg (builtins.length tags > 0) "At least one tag must be specified");
    writeShellScriptBin "docker-manifest" ''
      set -x # echo on
      if ${lib.getExe buildah} manifest exists "${manifestName}"; then
        ${lib.getExe buildah} manifest rm "${manifestName}"
      fi
      ${lib.getExe buildah} manifest create "${manifestName}"
      for IMAGE in ${builtins.toString images}; do
        ${lib.getExe buildah} manifest add "${manifestName}" "${sourceProtocol}$IMAGE"
      done
      for NAME in ${builtins.toString names}; do
        for TAG in ${builtins.toString tags}; do
          ${lib.getExe buildah} manifest push --all --format ${format} "${manifestName}" "${targetProtocol}$NAME:$TAG"
        done
      done
    ''
