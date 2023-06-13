{
  lib,
  writeShellApplication,
  buildah,
  images,
  name,
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
  writeShellApplication {
    name = "docker-manifest";
    text = ''
      set -x # echo on
      if ${lib.getExe buildah} manifest exists "${name}"; then
        ${lib.getExe buildah} manifest rm "${name}"
      fi
      ${lib.getExe buildah} manifest create "${name}"
      for IMAGE in ${builtins.toString images}; do
        ${lib.getExe buildah} manifest add "${name}" "${sourceProtocol}$IMAGE"
      done
      for TAG in ${builtins.toString tags}; do
        ${lib.getExe buildah} manifest push --all --format ${format} "${name}" "${targetProtocol}${name}:$TAG"
      done
    '';
  }
