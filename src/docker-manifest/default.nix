{
  lib,
  lib',
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
        { _module.args = { inherit lib'; }; }
        ./module.nix
        userModule
      ];
    }).config;

  podmanExe = lib.getExe' podman "podman";
  craneExe = lib.getExe' crane "crane";
in

assert lib.assertMsg (cfg.parsedTags != [ ]) "At least one `tag` must be set";

assert lib.assertMsg (cfg.registries != { }) "At least one `registry` must be set";

assert lib.assertMsg (
  cfg.imageFiles != [ ] || cfg.imageStreams != [ ]
) "At least one `imageFile` or `imageStream` must be set";

assert lib.assertMsg (
  !(cfg.github.enable && (cfg.github.actor == "" || cfg.github.repo == ""))
) "`github.actor` and `github.repo` must be set when `github.enable` is true";

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
    ${
      lib.concatLines (
        lib.mapAttrsToList (key: value: ''--annotation "${key}=${value}" \'') cfg.parsedAnnotations
      )
    } "${cfg.manifestName}" \
    || exit 1

  ${lib.concatMapStringsSep "\n" (imageFile: ''
    ${podmanExe} manifest add "${cfg.manifestName}" "docker-archive:${imageFile}" || exit 1
  '') cfg.imageFiles}

  ${lib.concatImapStringsSep "\n" (idx: imageStream: ''
    ${imageStream} | ${lib.getExe gzip} --fast > "$TMPDIR/image-stream-${toString idx}.tar.gz"
    ${podmanExe} manifest add "${cfg.manifestName}" "docker-archive:$TMPDIR/image-stream-${toString idx}.tar.gz" || exit 1
  '') cfg.imageStreams}

  set +x # echo off

  echo "Manifest: ${cfg.manifestName}"
  ${podmanExe} manifest inspect "${cfg.manifestName}"
  echo "Registries: ${toString (lib.attrNames cfg.registries)}"
  echo "Tags: ${toString cfg.parsedTags}"

  set -x # echo on

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
        "docker://${registryName}/${registryParams.repo}:${lib.head cfg.parsedTags}" \
        || exit 1

      ${lib.concatMapStringsSep "\n" (tag: ''
        ${craneExe} tag \
          "${registryName}/${registryParams.repo}:${lib.head cfg.parsedTags}" \
          "${tag}"
      '') (lib.tail cfg.parsedTags)}
    '') cfg.registries
  )}
''
