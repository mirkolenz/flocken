{
  lib,
  writeShellScriptBin,
  podman,
  coreutils,
  crane,
  git,
  gzip,
}:
userModule:
let
  cfg =
    (lib.evalModules {
      modules = [
        ./module.nix
        userModule
      ];
    }).config;

  mkCliFlags = lib.cli.toGNUCommandLineShell { };

  podmanExe = lib.getExe' podman "podman";
  craneExe = lib.getExe' crane "crane";

  illegalAnnotationChars = [
    "\""
    "'"
    ","
  ];
  replacementAnnotationChars = map (x: "") illegalAnnotationChars;
  escapeAnnotation = lib.replaceStrings illegalAnnotationChars replacementAnnotationChars;

  annotations = lib.mapAttrsToList (
    key: value: ''${key}=${escapeAnnotation value}''
  ) cfg.annotationLeaves;
in
assert lib.assertMsg (lib.length cfg.uniqueTags > 0) "At least one tag must be specified";
assert lib.assertMsg (
  lib.length cfg.imageFiles > 0 || lib.length cfg.imageStreams > 0
) "At least one image or imageStream must be specified";
assert lib.assertMsg (
  !(cfg.github.enable && lib.flocken.isEmpty cfg.github.actor && lib.flocken.isEmpty cfg.github.repo)
) "The GitHub actor and/or repo are empty";
writeShellScriptBin "docker-manifest" ''
  function cleanup {
    rm -rf "$TMPDIR"
    ${podmanExe} manifest rm "${cfg.manifestName}" || true

    ${lib.concatMapStringsSep "\n" (registryName: ''
      ${podmanExe} logout "${registryName}" || true
      ${craneExe} auth logout "${registryName}" || true
    '') (lib.attrNames cfg.registries)}
  }
  trap cleanup EXIT

  set -x # echo on
  TMPDIR="$(mktemp -d)"

  if ${podmanExe} manifest exists "${cfg.manifestName}"; then
    ${podmanExe} manifest rm "${cfg.manifestName}"
  fi

  ${podmanExe} manifest create \
    --annotation "org.opencontainers.image.created=$(${lib.getExe' coreutils "date"} --iso-8601=seconds)" \
    --annotation "org.opencontainers.image.revision=$(${lib.getExe git} rev-parse HEAD)" \
    ${mkCliFlags { annotation = annotations; }} \
    "${cfg.manifestName}" \
    || exit 1

  ${lib.concatMapStringsSep "\n" (imageFile: ''
    ${podmanExe} manifest add "${cfg.manifestName}" "docker-archive:${imageFile}" || exit 1
  '') cfg.imageFiles}

  ${lib.concatImapStringsSep "\n" (idx: imageStream: ''
    ${imageStream} | ${lib.getExe gzip} --fast > "$TMPDIR/image-stream-${toString idx}.tar.gz"
    ${podmanExe} manifest add "${cfg.manifestName}" "docker-archive:$TMPDIR/image-stream-${toString idx}.tar.gz" || exit 1
  '') cfg.imageStreams}

  ${podmanExe} manifest inspect "${cfg.manifestName}"

  ${lib.concatLines (
    lib.mapAttrsToList (registryName: registryParams: ''
      set +x # echo off

      echo "podman login ${registryName}"
      ${podmanExe} login \
        --username "${registryParams.username}" \
        --password "${registryParams.password}" \
        "${registryName}"

      echo "crane login ${registryName}"
      ${craneExe} auth login "${registryName}" \
        --username "${registryParams.username}" \
        --password "${registryParams.password}"

      set -x # echo on

      ${podmanExe} manifest push \
        --all \
        --format ${cfg.format} \
        "${cfg.manifestName}" \
        "docker://${registryName}/${registryParams.repo}:${cfg.firstTag}" \
        || exit 1

      ${lib.concatMapStringsSep "\n" (tag: ''
        ${craneExe} tag \
          "${registryName}/${registryParams.repo}:${cfg.firstTag}" \
          "${tag}"
      '') cfg.tags}
    '') cfg.registries
  )}
''
