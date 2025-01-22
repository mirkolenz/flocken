{
  lib,
  lib',
  writeShellApplication,
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

writeShellApplication {
  name = "docker-manifest";
  text = ''
    function cleanup {
      set -x # echo on

      rm -rf "$TMPDIR"
      ${podmanExe} manifest rm "${cfg.manifestName}" || true

      ${lib.concatMapStringsSep "\n" (registry: ''
        ${podmanExe} logout "${registry.name}" || true
        ${craneExe} auth logout "${registry.name}" || true
      '') (lib.attrValues cfg.registries)}
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
      } "${cfg.manifestName}"

    ${lib.concatMapStringsSep "\n" (imageFile: ''
      ${podmanExe} manifest add "${cfg.manifestName}" "docker-archive:${imageFile}"
    '') cfg.imageFiles}

    ${lib.concatImapStringsSep "\n" (idx: imageStream: ''
      ${imageStream} | ${lib.getExe gzip} --fast > "$TMPDIR/image-stream-${toString idx}.tar.gz"
      ${podmanExe} manifest add "${cfg.manifestName}" "docker-archive:$TMPDIR/image-stream-${toString idx}.tar.gz"
    '') cfg.imageStreams}

    set +x # echo off

    echo "Manifest: ${cfg.manifestName}"
    ${podmanExe} manifest inspect "${cfg.manifestName}"
    echo "Registries: ${toString (lib.attrNames cfg.registries)}"
    echo "Tags: ${toString cfg.parsedTags}"

    set -x # echo on

    ${lib.concatMapStringsSep "\n" (registry: ''
      set +x # echo off

      echo "podman login ${registry.name}"
      ${podmanExe} login \
        --username "${registry.username}" \
        --password "${registry.password}" \
        "${registry.name}"

      echo "crane login ${registry.name}"
      ${craneExe} auth login "${registry.name}" \
        --username "${registry.username}" \
        --password "${registry.password}"

      set -x # echo on

      ${podmanExe} manifest push \
        --all \
        --format ${cfg.format} \
        "${cfg.manifestName}" \
        "docker://${registry.name}/${registry.repo}:${lib.head cfg.parsedTags}"

      ${lib.concatMapStringsSep "\n" (tag: ''
        ${craneExe} tag \
          "${registry.name}/${registry.repo}:${lib.head cfg.parsedTags}" \
          "${tag}"
      '') (lib.tail cfg.parsedTags)}
    '') (lib.attrValues cfg.registries)}
  '';
}
