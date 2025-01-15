{
  lib,
  writeShellScriptBin,
  podman,
  coreutils,
  crane,
  git,
  gzip,
}:
{
  images ? [ ],
  imageStreams ? [ ],
  version ? null,
  branch ? null,
  defaultBranch ? null,
  tags ? [ ],
  autoTags ? { },
  registries ? { },
  annotations ? { },
  github ? { },
  format ? "oci",
  manifestName ? "flocken",
}:
let
  mkCliFlags = lib.cli.toGNUCommandLineShell { };
  isPreRelease = x: lib.hasInfix "-" x;
  optionalAttrPath = path: attrset: lib.flocken.attrByDottedPath path null attrset;

  podmanExe = lib.getExe' podman "podman";
  craneExe = lib.getExe' crane "crane";

  _github = {
    enable = false;
    actor = builtins.getEnv "GITHUB_ACTOR";
    repo = builtins.getEnv "GITHUB_REPOSITORY";
    branch = lib.optionalString (builtins.getEnv "GITHUB_REF_TYPE" == "branch") (
      builtins.getEnv "GITHUB_REF_NAME"
    );
    registry = "ghcr.io";
    enableRegistry = true;
    apiEndpoint = "https://api.github.com";
  } // github;

  githubData = lib.optionalAttrs (_github.enable) (
    lib.importJSON (builtins.fetchurl "${_github.apiEndpoint}/repos/${_github.repo}")
  );

  defaultAnnotations = {
    org.opencontainers.image = {
      version = _version;
    };
  };

  githubAnnotations = lib.optionalAttrs (_github.enable) {
    org.opencontainers.image = {
      # https://github.com/opencontainers/image-spec/blob/main/annotations.md
      authors = optionalAttrPath "owner.html_url" githubData;
      url =
        if (optionalAttrPath "homepage" githubData) != null then
          githubData.homepage
        else
          optionalAttrPath "html_url" githubData;
      source = optionalAttrPath "html_url" githubData;
      vendor = optionalAttrPath "owner.login" githubData;
      licenses = optionalAttrPath "license.spdx_id" githubData;
      title = optionalAttrPath "name" githubData;
      description = optionalAttrPath "description" githubData;
    };
  };

  _defaultBranch =
    if (optionalAttrPath "default_branch" githubData) != null then
      githubData.default_branch
    else if lib.flocken.isNotEmpty defaultBranch then
      defaultBranch
    else
      "main";

  _branch = if lib.flocken.isNotEmpty branch then branch else _github.branch;

  defaultRegistries = { };

  githubRegistries = {
    ${_github.registry} = {
      enable = _github.enable && _github.enableRegistry;
      repo = _github.repo;
      username = _github.actor;
      password = _github.token;
    };
  };

  _version = if lib.flocken.isNotEmpty version then lib.removePrefix "v" version else null;

  defaultAutoTags = {
    branch = true;
    latest = true;
    version = true;
    majorMinor = true;
    major = true;
  };

  _autoTags = defaultAutoTags // autoTags;

  _tags = lib.unique (
    tags
    ++ (lib.optional (_autoTags.branch && lib.flocken.isNotEmpty _branch) _branch)
    ++ (lib.optional (_autoTags.latest && _branch == _defaultBranch) "latest")
    ++ (lib.optional (_autoTags.version && lib.flocken.isNotEmpty _version) _version)
    ++ (lib.optional (
      _autoTags.majorMinor && lib.flocken.isNotEmpty _version && !isPreRelease _version
    ) (lib.versions.majorMinor _version))
    ++ (lib.optional (_autoTags.major && lib.flocken.isNotEmpty _version && !isPreRelease _version) (
      lib.versions.major _version
    ))
  );
  firstTag = lib.head _tags;

  _annotations = lib.filterAttrs (key: value: lib.flocken.isNotEmpty value) (
    lib.foldl' lib.recursiveUpdate (lib.flocken.getLeaves defaultAnnotations) (
      map lib.flocken.getLeaves [
        githubAnnotations
        annotations
      ]
    )
  );

  annotationFlags = {
    annotation = lib.mapAttrsToList (
      key: value:
      ''${key}=${
        lib.replaceStrings
          [
            "\""
            "'"
            ","
          ]
          [
            ""
            ""
            ""
          ]
          value
      }''
    ) _annotations;
  };

  _registries = lib.filterAttrs (key: value: lib.flocken.isNotEmpty value && value.enable == true) (
    lib.foldl' lib.recursiveUpdate defaultRegistries [
      githubRegistries
      registries
    ]
  );
in
assert lib.assertMsg (lib.length _tags > 0) "At least one tag must be specified";
assert lib.assertMsg (
  lib.length images > 0 || lib.length imageStreams > 0
) "At least one image or imageStream must be specified";
assert lib.assertMsg (
  !(_github.enable && lib.flocken.isEmpty _github.actor && lib.flocken.isEmpty _github.repo)
) "The GitHub actor and/or repo are empty";
writeShellScriptBin "docker-manifest" ''
  function cleanup {
    rm -rf "$TMPDIR"
    ${podmanExe} manifest rm "${manifestName}" || true

    ${lib.concatMapStringsSep "\n" (registryName: ''
      ${podmanExe} logout "${registryName}" || true
      ${craneExe} auth logout "${registryName}" || true
    '') (lib.attrNames _registries)}
  }
  trap cleanup EXIT

  set -x # echo on
  TMPDIR="$(mktemp -d)"

  if ${podmanExe} manifest exists "${manifestName}"; then
    ${podmanExe} manifest rm "${manifestName}"
  fi

  ${podmanExe} manifest create \
    --annotation "org.opencontainers.image.created=$(${lib.getExe' coreutils "date"} --iso-8601=seconds)" \
    --annotation "org.opencontainers.image.revision=$(${lib.getExe git} rev-parse HEAD)" \
    ${mkCliFlags annotationFlags} \
    "${manifestName}" \
    || exit 1

  ${lib.concatMapStringsSep "\n" (imageFile: ''
    ${podmanExe} manifest add "${manifestName}" "docker-archive:${imageFile}" || exit 1
  '') images}

  ${lib.concatImapStringsSep "\n" (idx: imageStream: ''
    ${imageStream} | ${lib.getExe gzip} --fast > "$TMPDIR/image-stream-${toString idx}.tar.gz"
    ${podmanExe} manifest add "${manifestName}" "docker-archive:$TMPDIR/image-stream-${toString idx}.tar.gz" || exit 1
  '') imageStreams}

  ${podmanExe} manifest inspect "${manifestName}"

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
        --format ${format} \
        "${manifestName}" \
        "docker://${registryName}/${registryParams.repo}:${firstTag}" \
        || exit 1

      ${lib.concatMapStringsSep "\n" (tag: ''
        ${craneExe} tag \
          "${registryName}/${registryParams.repo}:${firstTag}" \
          "${tag}"
      '') _tags}
    '') _registries
  )}
''
