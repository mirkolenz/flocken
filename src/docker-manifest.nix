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
  cleanVersion = lib.removePrefix "v" version;
  manifestName = "flocken";
  allNames = names ++ (lib.optional (name != "") name);
  allTags =
    extraTags
    ++ (lib.optional (branch != "") branch)
    ++ (lib.optional latest "latest")
    ++ (lib.optional (cleanVersion != "") cleanVersion)
    ++ (lib.optionals (cleanVersion != "" && !lib.hasInfix "-" cleanVersion) [
      (lib.versions.majorMinor cleanVersion)
      (lib.versions.major cleanVersion)
    ]);
in
  assert (lib.assertMsg (builtins.length allNames > 0) "At least one name must be specified");
  assert (lib.assertMsg (builtins.length allTags > 0) "At least one tag must be specified");
    writeShellScriptBin "docker-manifest" ''
      set -x # echo on
      if ${lib.getExe buildah} manifest exists "${manifestName}"; then
        ${lib.getExe buildah} manifest rm "${manifestName}"
      fi
      ${lib.getExe buildah} manifest create "${manifestName}"
      for IMAGE in ${builtins.toString images}; do
        ${lib.getExe buildah} manifest add "${manifestName}" "${sourceProtocol}$IMAGE"
      done
      for name in ${builtins.toString allNames}; do
        for tag in ${builtins.toString allTags}; do
          ${lib.getExe buildah} manifest push --all --format ${format} "$manifest" "${targetProtocol}$name:$tag"
        done
      done
    ''
