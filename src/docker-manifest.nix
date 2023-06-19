{
  lib,
  writeShellScriptBin,
  buildah,
  images,
  name,
  names ? [],
  branch ? "",
  latest ? (builtins.elem branch ["main" "master"]),
  version ? "",
  sourceProtocol ? "docker-archive:",
  targetProtocol ? "docker://",
  format ? "v2s2",
  extraTags ? [],
  ...
}: let
  cleanVersion = lib.removePrefix "v" version;
  versionComponents = lib.splitString "." cleanVersion;
  manifestName = "flocken";
  allNames = names ++ [name];
  tags =
    extraTags
    ++ (lib.optional (branch != "") branch)
    ++ (lib.optional latest "latest")
    ++ (lib.optional (cleanVersion != "") cleanVersion)
    ++ (lib.optionals (cleanVersion != "" && !lib.hasInfix "-" cleanVersion) [
      (lib.concatStringsSep "." (lib.sublist 0 2 versionComponents))
      (builtins.elemAt versionComponents 0)
    ]);
in
  writeShellScriptBin ''
    set -x # echo on
    if ${lib.getExe buildah} manifest exists "${manifestName}"; then
      ${lib.getExe buildah} manifest rm "${manifestName}"
    fi
    ${lib.getExe buildah} manifest create "${manifestName}"
    for IMAGE in ${builtins.toString images}; do
      ${lib.getExe buildah} manifest add "${manifestName}" "${sourceProtocol}$IMAGE"
    done
    # shellcheck disable=SC2043
    for NAME in ${builtins.toString allNames}; do
      # shellcheck disable=SC2043
      for TAG in ${builtins.toString tags}; do
        ${lib.getExe buildah} manifest push --all --format ${format} "${manifestName}" "${targetProtocol}$NAME:$TAG"
      done
    done
  ''
