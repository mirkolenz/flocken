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
  tags ? [],
  extraTags ? [],
  annotations ? {},
  ...
}: let
  cleanVersion = lib.removePrefix "v" version;
  manifestName = "flocken";
  allNames = names ++ (lib.optional (name != "") name);
  allTags =
    tags
    ++ extraTags
    ++ (lib.optional (branch != "") branch)
    ++ (lib.optional latest "latest")
    ++ (lib.optional (cleanVersion != "") cleanVersion)
    ++ (lib.optionals (cleanVersion != "" && !lib.hasInfix "-" cleanVersion) [
      (lib.versions.majorMinor cleanVersion)
      (lib.versions.major cleanVersion)
    ]);

  getLeaves = attrset: path:
    if builtins.isAttrs attrset
    then
      builtins.concatLists (
        lib.mapAttrsToList
        (key: value: getLeaves value (path ++ [key]))
        attrset
      )
    else [
      {
        name = builtins.concatStringsSep "." path;
        value = attrset;
      }
    ];
  parsedAnnotations = builtins.listToAttrs (getLeaves annotations []);
in
  assert (lib.assertMsg (builtins.length allNames > 0) "At least one name must be specified");
  assert (lib.assertMsg (builtins.length allTags > 0) "At least one tag must be specified");
    writeShellScriptBin "docker-manifest" ''
      set -x # echo on
      if ${lib.getExe buildah} manifest exists "${manifestName}"; then
        ${lib.getExe buildah} manifest rm "${manifestName}"
      fi
      manifest=$(${lib.getExe buildah} manifest create "${manifestName}")
      for image in ${builtins.toString images}; do
        manifestOutput=$(${lib.getExe buildah} manifest add "$manifest" "${sourceProtocol}$image")
        ${
        if builtins.length (builtins.attrNames parsedAnnotations) > 0
        then ''
          manifestSplit=($manifestOutput)
          digest=''${manifestSplit[1]}
          ${lib.getExe buildah} manifest annotate \
            ${builtins.toString (lib.mapAttrsToList (key: value: "--annotation \"${key}=${value}\"") parsedAnnotations)} \
            "$manifest" "$digest"
        ''
        else ""
      }
      done
      ${lib.getExe buildah} manifest inspect "$manifest"
      for name in ${builtins.toString allNames}; do
        for tag in ${builtins.toString allTags}; do
          ${lib.getExe buildah} manifest push --all --format ${format} "$manifest" "${targetProtocol}$name:$tag"
        done
      done
    ''
