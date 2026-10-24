{
  config,
  lib,
  ...
}:
let
  inherit (lib) types mkOption mkEnableOption;
  mkDisableOption =
    name:
    (mkEnableOption name)
    // {
      default = true;
      example = false;
    };
  # Kept for compatibility, a definition only causes a warning.
  mkDeprecatedOption =
    type:
    mkOption {
      type = types.nullOr type;
      default = null;
      visible = false;
    };
  deprecations = {
    "github.branch" = "use `branch` instead";
    "github.enableRegistry" = "use `registries.\"${config.github.registry}\".enable` instead";
    "github.apiEndpoint" = "the metadata is read from the event payload";
    "manifestName" = "the manifest name is generated";
  };
in
{
  imports = map (name: lib.mkRenamedOptionModule [ name ] [ "images" ]) [
    "imageFiles"
    "imageStreams"
  ];
  options = {
    warnings = mkOption {
      type = types.listOf types.str;
      default = [ ];
      internal = true;
      description = "Warnings shown when evaluating the configuration.";
    };
    manifestName = mkDeprecatedOption types.str;
    images = mkOption {
      type = types.nonEmptyListOf types.package;
      example = lib.literalExpression "with self.packages; [ x86_64-linux.image aarch64-linux.image ]";
      description = ''
        Nix-built images to be added to the manifest, either archives (e.g., `pkgs.dockerTools.buildLayeredImage`) or streams (e.g., `pkgs.dockerTools.streamLayeredImage`).
        _Note:_ This should be a list of identical images for different architectures.
      '';
    };
    version = mkOption {
      type = types.str;
      default = "$VERSION";
      description = "Semantic version of the image (e.g., `v1.0.0` or `1.0.0`).";
    };
    branch = mkOption {
      type = types.nullOr types.str;
      default = null;
      defaultText = "`$GITHUB_REF_NAME` or `$CI_COMMIT_BRANCH` in branch pipelines if the GitHub or GitLab integration is enabled, else the checked out git branch";
      description = ''
        Name of the git branch (e.g., `main`).
      '';
    };
    defaultBranch = mkOption {
      type = types.nullOr types.str;
      default = null;
      defaultText = "the repository's default branch if the GitHub or GitLab integration is enabled, else `main`";
      description = ''
        Name of the git branch that is used as default for the `latest` tag.
      '';
    };
    tags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of custom/additional tags to be added to the manifest.";
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
              tls = mkOption {
                type = types.enum [
                  "enabled"
                  "insecure"
                  "disabled"
                ];
                default = "enabled";
                description = "Whether to use TLS, `insecure` skips the certificate verification and `disabled` uses plain HTTP.";
              };
            };
          }
        )
      );
      default = { };
      description = ''
        Configuration for the Docker registries to be used.
        The key is the name of the registry (e.g., `ghcr.io`).
        The index is pushed to and signed in the first registry, then copied with its signatures to the others.
      '';
    };
    annotations = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Annotations for the manifest, nested attribute sets are flattened to dotted keys.
        Most `org.opencontainers.image` annotations are set automatically if the GitHub or GitLab integration is enabled.
        The `created` and `revision` annotations are read from the git repository in the working directory if there is one.
      '';
    };
    github = mkOption {
      type = types.submodule {
        options = {
          enable = (mkEnableOption "GitHub integration") // {
            description = ''
              Whether the GitHub integration is enabled.
              If set to `true`, the repository metadata is read from the GitHub Actions environment and event payload at runtime.
            '';
          };
          token = mkOption {
            type = types.str;
            default = "$GITHUB_TOKEN";
            description = ''
              GitHub access token.
              Used as default value for `registries."ghcr.io".password`.
            '';
          };
          actor = mkOption {
            type = types.str;
            default = "$GITHUB_ACTOR";
            description = ''
              GitHub actor.
              Used as default value for `registries."ghcr.io".username`.
            '';
          };
          repo = mkOption {
            type = types.str;
            default = "$GITHUB_REPOSITORY";
            description = ''
              Full name of the GitHub repository (e.g., `mirkolenz/flocken`).
              Used as default value for `registries."ghcr.io".repo`.
            '';
          };
          registry = mkOption {
            type = types.str;
            default = "ghcr.io";
            description = "Name of the GitHub registry";
          };
          branch = mkDeprecatedOption types.str;
          enableRegistry = mkDeprecatedOption types.bool;
          apiEndpoint = mkDeprecatedOption types.str;
        };
      };
      default = { };
      description = "GitHub integration configuration";
    };
    gitlab = mkOption {
      type = types.submodule {
        options = {
          enable = (mkEnableOption "GitLab integration") // {
            description = ''
              Whether the GitLab integration is enabled.
              If set to `true`, the project metadata is read from the predefined variables of GitLab CI/CD at runtime.
            '';
          };
          registry = mkOption {
            type = types.str;
            default = "$CI_REGISTRY";
            description = "Name of the GitLab container registry.";
          };
          repo = mkOption {
            type = types.str;
            default = "$CI_PROJECT_PATH";
            description = ''
              Full path of the GitLab project (e.g., `mirkolenz/flocken`).
              Used as default value for `registries."$CI_REGISTRY".repo`.
            '';
          };
          username = mkOption {
            type = types.str;
            default = "$CI_REGISTRY_USER";
            description = ''
              Username for the GitLab container registry.
              Used as default value for `registries."$CI_REGISTRY".username`.
            '';
          };
          password = mkOption {
            type = types.str;
            default = "$CI_REGISTRY_PASSWORD";
            description = ''
              Password for the GitLab container registry.
              Used as default value for `registries."$CI_REGISTRY".password`.
            '';
          };
        };
      };
      default = { };
      description = "GitLab integration configuration";
    };
    format = mkOption {
      type = types.enum [
        "oci"
        "v2s2"
      ];
      default = "oci";
      description = "The format of the manifest";
    };
    compression = mkOption {
      type = types.nullOr (
        types.enum [
          "gzip"
          "zstd"
        ]
      );
      default = "gzip";
      description = "Compression of the image layers, `null` keeps them as they are in the images.";
    };
    cosign = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "signing the pushed manifest with cosign";
          recursive = mkDisableOption "signing each per-platform image in the manifest list";
          key = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "cosign.key";
            description = "Path or KMS URI of a cosign key. Null means keyless OIDC signing.";
          };
          extraArgs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra arguments passed to cosign sign.";
          };
        };
      };
      default = { };
      description = "Configuration for signing the manifest with cosign.";
    };
  };
  config = lib.mkMerge [
    {
      warnings = lib.mapAttrsToList (name: hint: "flocken: `${name}` is deprecated, ${hint}.") (
        lib.filterAttrs (
          name: _: lib.getAttrFromPath (lib.splitString "." name) config != null
        ) deprecations
      );
      branch = lib.mkIf (config.github.branch != null) (lib.mkDefault config.github.branch);
    }
    (lib.mkIf config.gitlab.enable {
      registries.${config.gitlab.registry} = lib.mapAttrs (_: lib.mkDefault) {
        inherit (config.gitlab) repo username password;
      };
    })
    (lib.mkIf config.github.enable {
      registries.${config.github.registry} = lib.mapAttrs (_: lib.mkDefault) {
        repo = config.github.repo;
        username = config.github.actor;
        password = config.github.token;
        enable = lib.defaultTo true config.github.enableRegistry;
      };
    })
  ];
}
