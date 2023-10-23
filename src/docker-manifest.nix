{
  lib,
  writeShellScriptBin,
  buildah,
  coreutils,
  git,
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
  isEnabled = x: builtins.hasAttr "enable" x && x.enable == true;
  isEmpty = x: x == null || x == "" || x == {};
  isNotEmpty = x: x != null && x != "" && x != {};
  isPreRelease = x: lib.hasInfix "-" x;
  optionalPath = path: attrset: lib.attrByPath (lib.splitString "." path) null attrset;

  getLeavesRecursive = attrset: path:
    if builtins.isAttrs attrset
    then
      builtins.concatLists (
        lib.mapAttrsToList
        (key: value: getLeavesRecursive value (path ++ [key]))
        attrset
      )
    else [
      {
        name = builtins.concatStringsSep "." path;
        value = attrset;
      }
    ];
  getLeaves = attrset: builtins.listToAttrs (getLeavesRecursive attrset []);

  buildahExe = lib.getExe' buildah "buildah";

  _github =
    {
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
    if isEnabled _github
    then
      builtins.fromJSON (builtins.readFile (builtins.fetchurl {
        url = "${_github.apiEndpoint}/repos/${_github.repo}";
      }))
    else {};

  defaultAnnotations = {
    org.opencontainers.image = {
      version = _version;
      created = "$(${lib.getExe' coreutils "date"} --iso-8601=seconds)";
      revision = "$(${lib.getExe git} rev-parse HEAD)";
    };
  };

  githubAnnotations = lib.optionalAttrs (isEnabled _github) {
    org.opencontainers.image = {
      # https://github.com/opencontainers/image-spec/blob/main/annotations.md
      authors = optionalPath "owner.html_url" githubData;
      url =
        if (optionalPath "homepage" githubData) != null
        then githubData.homepage
        else optionalPath "html_url" githubData;
      source = optionalPath "html_url" githubData;
      vendor = optionalPath "owner.login" githubData;
      licenses = optionalPath "license.spdx_id" githubData;
      title = optionalPath "name" githubData;
      description = optionalPath "description" githubData;
    };
  };

  _defaultBranch =
    if (optionalPath "default_branch" githubData) != null
    then githubData.default_branch
    else if isNotEmpty defaultBranch
    then defaultBranch
    else "main";

  _branch =
    if isNotEmpty _github.branch
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
    if isNotEmpty version
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
    ++ (lib.optional (_autoTags.branch && isNotEmpty _branch) _branch)
    ++ (lib.optional (_autoTags.latest && _branch == _defaultBranch) "latest")
    ++ (lib.optional (_autoTags.version && isNotEmpty _version) _version)
    ++ (lib.optional (_autoTags.majorMinor && isNotEmpty _version && !isPreRelease _version) (lib.versions.majorMinor _version))
    ++ (lib.optional (_autoTags.major && isNotEmpty _version && !isPreRelease _version) (lib.versions.major _version))
  );

  _annotations =
    lib.filterAttrs
    (key: value: isNotEmpty value)
    (
      builtins.foldl'
      lib.recursiveUpdate
      (getLeaves defaultAnnotations)
      (builtins.map getLeaves [githubAnnotations annotations])
    );

  _registries =
    lib.filterAttrs
    (key: value: isNotEmpty value && value.enable == true)
    (
      builtins.foldl'
      lib.recursiveUpdate
      defaultRegistries
      [githubRegistries registries]
    );
in
  assert (lib.assertMsg (builtins.length _tags > 0) "At least one tag must be specified");
  assert (lib.assertMsg (!(_github.enable && isEmpty _github.actor && isEmpty _github.repo)) "The GitHub actor and/or repo are empty");
    writeShellScriptBin "docker-manifest" ''
      set -x # echo on

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
          set -x # echo on

          for tag in ${builtins.toString _tags}; do
            ${buildahExe} manifest push --all \
              --format ${format} \
              "$manifest" \
              "${targetProtocol}${registryName}/${registryParams.repo}:$tag"
          done

          ${buildahExe} logout "${registryName}"
        '')
        _registries)}
    ''
