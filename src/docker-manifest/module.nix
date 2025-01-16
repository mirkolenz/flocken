{
  config,
  lib,
  lib',
  ...
}:
let
  inherit (lib) types mkOption mkEnableOption;
  isPreRelease = x: lib.hasInfix "-" x;
  mkDisableOption =
    name:
    (mkEnableOption name)
    // {
      default = true;
      example = false;
    };
  githubData = lib.optionalAttrs (config.github.enable) (
    lib.importJSON (builtins.fetchurl "${config.github.apiEndpoint}/repos/${config.github.repo}")
  );
  illegalAnnotationChars = [
    "\""
    "'"
    ","
  ];
  replacementAnnotationChars = map (x: "") illegalAnnotationChars;
  escapeAnnotations =
    name: value: lib.replaceStrings illegalAnnotationChars replacementAnnotationChars value;
in
{
  imports = [
    (lib.mkAliasOptionModule [ "images" ] [ "imageFiles" ])
  ];
  options = {
    imageFiles = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        List of Docker images to be added to the manifest.
        Can for instance be produced using `dockerTools.buildLayeredImage`.
        _Note:_ This should be a list of identical images for different architectures.
      '';
    };
    imageStreams = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        List of Docker image streams to be added to the manifest.
        Can for instance be produced using `dockerTools.streamLayeredImage`.
        _Note:_ This should be a list of identical images for different architectures.
      '';
    };
    version = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Semantic version of the image (e.g., `v1.0.0` or `1.0.0`).";
    };
    parsedVersion = mkOption {
      type = types.nullOr types.str;
      readOnly = true;
      internal = true;
      description = "The version without the 'v' prefix";
    };
    branch = mkOption {
      type = types.nullOr types.str;
      default = null;
      defaultText = "github.branch || null";
      description = ''
        Name of the git branch (e.g., `main`).
      '';
    };
    defaultBranch = mkOption {
      type = types.str;
      default = "github.defaultBranch || 'main'";
      defaultText = "if `github.enable` then `$GITHUB_DEFAULT_BRANCH` else `main`";
      description = ''
        Name of the git branch that is used as default for the `latest` tag.
      '';
    };
    tags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of custom/additional tags to be added to the manifest.";
    };
    uniqueTags = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      internal = true;
      description = "List of unique tags";
    };
    autoTags = mkOption {
      type = types.submodule {
        options = {
          branch = mkDisableOption "add a tag based on the branch name";
          latest = mkDisableOption "add a 'latest' tag if `branch == defaultBranch`";
          version = mkDisableOption "add a tag based on the version (e.g., `1.2.3`)";
          majorMinor = mkDisableOption "add a tag based on the major and minor version (e.g., `1.2`)";
          major = mkDisableOption "add a tag based on the major version (e.g., `1`)";
        };
      };
      default = { };
      description = "Configuration for tags that are generated automatically.";
    };
    registries = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              enable = mkDisableOption "pushing to the registry";
              name = mkOption {
                type = types.str;
                description = "The name/domain of the registry";
                default = name;
              };
              repo = mkOption {
                type = types.str;
                description = "Fully qualified name of the Docker image in the registry (e.g., `mirkolenz/flocken`).";
              };
              username = mkOption {
                type = types.str;
                description = "Username for pushing to the registry.";
              };
              password = mkOption {
                type = types.str;
                description = "Password for pushing to the registry.";
              };
            };
          }
        )
      );
      default = { };
      description = ''
        Configuration for the Docker registries to be used.
        The key is the name of the registry (e.g., `ghcr.io`).
      '';
    };
    annotations = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Annotations for the manifest.
        Most `org.opencontainers.image` annotations are set automatically if the GitHub option is enabled.
      '';
    };
    annotationLeaves = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      internal = true;
      description = "Flattened annotations";
    };
    github = mkOption {
      type = types.submodule {
        options = {
          enable = (mkEnableOption "GitHub integration") // {
            description = ''
              Whether the GitHub integration is enabled.
              If set to `true`, you need to run nix with the `--impure` flag in order to access the GitHub API.
            '';
          };
          token = mkOption {
            type = types.str;
            default = "$GITHUB_TOKEN";
            defaultText = "$GITHUB_TOKEN";
            description = ''
              GitHub access token.
              Used as default value for `registries."ghcr.io".password`.
            '';
          };
          actor = mkOption {
            type = types.nullOr types.str;
            default = lib.maybeEnv "GITHUB_ACTOR" null;
            defaultText = "$GITHUB_ACTOR || null";
            description = ''
              GitHub actor.
              Used as default value for `registries."ghcr.io".username`.
            '';
          };
          repo = mkOption {
            type = types.nullOr types.str;
            default = lib.maybeEnv "GITHUB_REPOSITORY" null;
            defaultText = "$GITHUB_REPOSITORY || null";
            description = ''
              Full name of the GitHub repository (e.g., `mirkolenz/flocken`).
              Used as default value for `registries."ghcr.io".repo`.
            '';
          };
          branch = mkOption {
            type = types.nullOr types.str;
            default =
              if (builtins.getEnv "GITHUB_REF_TYPE" == "branch") then
                lib.maybeEnv "GITHUB_REF_NAME" null
              else
                null;
            defaultText = "$GITHUB_REF_NAME || null";
            description = "Name of the git branch.";
          };
          registry = mkOption {
            type = types.str;
            default = "ghcr.io";
            description = "Name of the GitHub registry";
          };
          enableRegistry = mkDisableOption "the GitHub container registry";
          apiEndpoint = mkOption {
            type = types.str;
            default = "https://api.github.com";
            description = ''
              GitHub API endpoint.
              Can be used for custom GitHub installations.
            '';
          };
        };
      };
      default = { };
      description = "GitHub integration configuration";
    };
    format = mkOption {
      type = types.enum [
        "oci"
        "v2s2"
      ];
      default = "oci";
      description = "The format of the manifest";
    };
    manifestName = mkOption {
      type = types.str;
      default = "flocken";
      description = "The name of the manifest";
    };
  };
  config = lib.mkMerge [
    {
      parsedVersion =
        if lib'.isNotEmpty config.version then lib.removePrefix "v" config.version else null;
      uniqueTags = lib.unique (lib.filter lib'.isNotEmpty config.tags);
      annotations.org.opencontainers.image = {
        version = config.parsedVersion;
      };
      annotationLeaves = lib.mapAttrs escapeAnnotations (
        lib.filterAttrs (name: value: lib'.isNotEmpty value) (lib'.getLeaves config.annotations)
      );
      tags = lib.concatLists [
        (lib.optional config.autoTags.branch config.branch)
        (lib.optional (config.autoTags.latest && config.branch == config.defaultBranch) "latest")
        (lib.optional config.autoTags.version config.parsedVersion)
        (lib.optional (
          config.autoTags.majorMinor && config.parsedVersion != null && !isPreRelease config.parsedVersion
        ) (lib.versions.majorMinor config.parsedVersion))
        (lib.optional (
          config.autoTags.major && config.parsedVersion != null && !isPreRelease config.parsedVersion
        ) (lib.versions.major config.parsedVersion))
      ];
    }
    (lib.mkIf config.github.enable {
      branch = lib.mkDefault config.github.branch;
      defaultBranch = lib.mkIf ((githubData.default_branch or null) != null) (
        lib.mkDefault githubData.default_branch
      );
      registries.${config.github.registry} = {
        enable = config.github.enableRegistry;
        repo = config.github.repo;
        username = config.github.actor;
        password = config.github.token;
      };
      annotations.org.opencontainers.image = {
        # https://github.com/opencontainers/image-spec/blob/main/annotations.md
        authors = githubData.owner.html_url or null;
        url = githubData.homepage or null;
        source = githubData.html_url or null;
        vendor = githubData.owner.login or null;
        licenses = githubData.license.spdx_id or null;
        title = githubData.name or null;
        description = githubData.description or null;
      };
    })
  ];
}
