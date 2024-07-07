{
  lib,
  writeShellScriptBin,
  buildah,
  coreutils,
  crane,
  git,
}: {
  images,
  version ? null,
  branch ? null,
  defaultBranch ? null,
  tags ? [],
  autoTags ? {},
  registries ? {},
  annotations ? {},
  github ? {},
  sourceProtocol ? "docker-archive:",
  targetProtocol ? "docker://",
  format ? "oci",
  manifestName ? "flocken",
}: let
  isPreRelease = x: lib.hasInfix "-" x;
  optionalAttrPath = path: attrset: lib.flocken.attrByDottedPath path null attrset;

  buildahExe = lib.getExe' buildah "buildah";
  craneExe = lib.getExe' crane "crane";

  _github =
    {
      enable = false;
      actor = builtins.getEnv "GITHUB_ACTOR";
      repo = builtins.getEnv "GITHUB_REPOSITORY";
      branch =
        lib.optionalString
        (builtins.getEnv "GITHUB_REF_TYPE" == "branch")
        (builtins.getEnv "GITHUB_REF_NAME");
      registry = "ghcr.io";
      enableRegistry = true;
      apiEndpoint = "https://api.github.com";
    }
    // github;

  githubData =
    if _github.enable
    then
      builtins.fromJSON (builtins.readFile (builtins.fetchurl {
        url = "${_github.apiEndpoint}/repos/${_github.repo}";
      }))
    else {};

  defaultAnnotations = {
    org.opencontainers.image = {
      version = _version;
      created = ''"$datetimeNow"'';
      revision = "$(${lib.getExe git} rev-parse HEAD)";
    };
  };

  githubAnnotations = lib.optionalAttrs (_github.enable) {
    org.opencontainers.image = {
      # https://github.com/opencontainers/image-spec/blob/main/annotations.md
      authors = optionalAttrPath "owner.html_url" githubData;
      url =
        if (optionalAttrPath "homepage" githubData) != null
        then githubData.homepage
        else optionalAttrPath "html_url" githubData;
      source = optionalAttrPath "html_url" githubData;
      vendor = optionalAttrPath "owner.login" githubData;
      licenses = optionalAttrPath "license.spdx_id" githubData;
      title = optionalAttrPath "name" githubData;
      description = optionalAttrPath "description" githubData;
    };
  };

  _defaultBranch =
    if (optionalAttrPath "default_branch" githubData) != null
    then githubData.default_branch
    else if lib.flocken.isNotEmpty defaultBranch
    then defaultBranch
    else "main";

  _branch =
    if lib.flocken.isNotEmpty _github.branch
    then _github.branch
    else branch;

  defaultRegistries = {};

  githubRegistries = {
    ${_github.registry} = {
      enable = _github.enable && _github.enableRegistry;
      repo = _github.repo;
      username = _github.actor;
      password = _github.token;
    };
  };

  _version =
    if lib.flocken.isNotEmpty version
    then lib.removePrefix "v" version
    else null;

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
    ++ (lib.optional (_autoTags.majorMinor && lib.flocken.isNotEmpty _version && !isPreRelease _version) (lib.versions.majorMinor _version))
    ++ (lib.optional (_autoTags.major && lib.flocken.isNotEmpty _version && !isPreRelease _version) (lib.versions.major _version))
  );

  _annotations =
    lib.filterAttrs
    (key: value: lib.flocken.isNotEmpty value)
    (
      builtins.foldl'
      lib.recursiveUpdate
      (lib.flocken.getLeaves defaultAnnotations)
      (builtins.map lib.flocken.getLeaves [githubAnnotations annotations])
    );

  _registries =
    lib.filterAttrs
    (key: value: lib.flocken.isNotEmpty value && value.enable == true)
    (
      builtins.foldl'
      lib.recursiveUpdate
      defaultRegistries
      [githubRegistries registries]
    );
in
  assert (lib.assertMsg (builtins.length _tags > 0) "At least one tag must be specified");
  assert (lib.assertMsg (!(_github.enable && lib.flocken.isEmpty _github.actor && lib.flocken.isEmpty _github.repo)) "The GitHub actor and/or repo are empty");
    writeShellScriptBin "docker-manifest" ''
      set -x # echo on

      datetimeNow="$(${lib.getExe' coreutils "date"} --iso-8601=seconds)"

      if ${buildahExe} manifest exists "${manifestName}"; then
        ${buildahExe} manifest rm "${manifestName}"
      fi

      manifest=$(${buildahExe} manifest create "${manifestName}")

      for image in ${builtins.toString images}; do
        manifestOutput=$(${buildahExe} manifest add "$manifest" "${sourceProtocol}$image")
        ${
        if builtins.length (builtins.attrNames _annotations) > 0
        then ''
          manifestSplit=($manifestOutput)
          digest=''${manifestSplit[1]}
          ${buildahExe} manifest annotate \
            ${builtins.toString (lib.mapAttrsToList (key: value: ''--annotation "${key}=${value}"'') _annotations)} \
            "$manifest" "$digest"
        ''
        else ""
      }
      done

      ${buildahExe} manifest inspect "$manifest"

      ${lib.concatLines (lib.mapAttrsToList
        (registryName: registryParams: ''
          set +x # echo off
          echo "buildah login ${registryName}"
          ${buildahExe} login \
            --username "${registryParams.username}" \
            --password "${registryParams.password}" \
            "${registryName}"
          echo "crane login ${registryName}"
          ${craneExe} auth login "${registryName}" \
            --username "${registryParams.username}" \
            --password "${registryParams.password}"
          set -x # echo on

          firstTag=${builtins.head _tags}
          ${buildahExe} manifest push --all \
            --format ${format} \
            "$manifest" \
            "${targetProtocol}${registryName}/${registryParams.repo}:$firstTag"

          for tag in ${builtins.toString _tags}; do
            ${craneExe} tag \
              "${registryName}/${registryParams.repo}:$firstTag" \
              "$tag"
          done

          ${buildahExe} logout "${registryName}"
          ${craneExe} auth logout "${registryName}"
        '')
        _registries)}
    ''
