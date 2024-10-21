# Flocken

Flocken (German for "flakes") is a collection of utilities for nix flakes.

## Usage

The project supports semantic versioning, so we advise to pin the major version (e.g., `v2`) to avoid breaking changes.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flocken = {
      url = "github:mirkolenz/flocken/v2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {nixpkgs, flocken, ...}:  {};
}
```

Flocken currently provides the following attributes:

### [`flocken.lib`](./lib/default.nix)

- `getModules DIRECTORY`: Get all modules in a directory.
  Can for instance be used to automatically import all modules in a directory.
  Directories containing a `default.nix` file are considered modules.
  Paths starting with `_` are ignored.
- `optionalPath PATH`: Get a path as a list if it exists.
  Returns an empty list if the path does not exist.
  Useful for adding optional paths to import statements.
- `isEmpty VALUE`: Check if a value of arbitrary type is empty.
- `isNonEmpty VALUE`: Check if a value of arbitrary type is non-empty.
- `isEnabled ATTRS`: Checks if an attrset has a key with the name `enable` set to `true`.
- `githubSshKeys {user, sha256}`: Returns a list of GitHub SSH keys for a user.
- `getLeaves ATTRS`: Get all leaves of an attrset.
- `attrByDottedPath PATH DEFAULT ATTRS`: Return an attribute from nested attribute sets.
- `getAttrFromDottedPath PATH ATTRS`: Like `attrByDottedPath`, but without a default value. If it doesn't find the path it will throw an error.
- `setAttrByDottedPath PATH VALUE`: Create a new attribute set with value set at the nested attribute location specified in PATH.

### [`flocken.legacyPackages.${system}.mkDockerManifest`](./src/docker-manifest.nix)

Create and push a Docker manifest to a registry.
This is particularly useful for multi-arch images.
The function takes the following attrset as an argument:

- `images`: List of Docker images to be added to the manifest. Can for instance be produced using `dockerTools.buildLayeredImage`. _Note:_ This should be a list of identical images for different architectures.
- `imageStreams`: List of Docker image streams to be added to the manifest. Can for instance be produced using `dockerTools.streamLayeredImage`. _Note:_ This should be a list of identical images for different architectures.
- `version`: Semantic version of the image (e.g., `v1.0.0` or `1.0.0`).
- `branch`: Name of the git branch (e.g., `main`). Defaults to the environment variable `GITHUB_REF_NAME` in GitHub actions if `GITHUB_REF_TYPE == "branch"`.
- `defaultBranch`: Name of the git branch that is used as default for the `latest` tag. Defaults to `main`. If the GitHub option is enabled, this option is set automatically.
- `tags`: List of additional tags to be added to the manifest.
- `autoTags`: Attrset with configuration for tags that are generated automatically:
  - `branch`: Boolean indicating whether the branch name should be added as a tag.
  - `latest`: Boolean indicating whether the `latest` tag should be added as a tag. If `branch == defaultBranch`, this is set to `true` by default.
  - `version`: Boolean indicating whether the version should be added as a tag.
  - `majorMinor`: Boolean indicating whether the major and minor version (e.g., `1.0`) should be added as a tag.
  - `major`: Boolean indicating whether the major version (e.g., `1`) should be added as a tag.
- `registries`: Attrset with configuration for the Docker registries to be used. The key is the name of the registry (e.g., `ghcr.io`) and the value is an attrset with the following attributes:
  - `enable`: Boolean indicating whether the registry should be used.
  - `repo`: Fully qualified name of the Docker image in the registry (e.g., `mirkolenz/flocken`).
  - `username`: Username for pushing to the registry.
  - `password`: Password for pushing to the registry.
- `annotations`: List of annotations to be added to the manifest. If the GitHub option is enabled, most `org.opencontainers.image` annotations are added automatically for public repositories.
- `github`: Attrset with configuration for GitHub. The following attributes are supported:
  - `enable`: Boolean indicating whether the GitHub defaults are applied. If set to `true`, you need to run nix with the `--impure` flag in order to access the GitHub API.
  - `token`: GitHub access token. Used as default value for `registries."ghcr.io".password`.
  - `actor`: GitHub actor. Used as default value for `registries."ghcr.io".username`. Defaults to environment variable `GITHUB_ACTOR` in GitHub actions.
  - `repo`: Full name of the GitHub repository (e.g., `mirkolenz/flocken`). Used as default value for `registries."ghcr.io".repo`. Defaults to environment variable `GITHUB_REPOSITORY` in GitHub actions.
  - `registry`: Name of the container registry. Can be used to override the default `ghcr.io`.
  - `apiEndpoint`: URL of the GitHub API endpoint. Can be used to override the default `https://api.github.com`.

Some arguments (e.g., `version`) differ between invocations and thus need to be provided in a dynamic fashion.
We recommend to use environment variables for this purpose.
For instance, when running in a GitHub action, you only have to provide a value for `VERSION` and `GH_TOKEN` and then can use the following snippet:

```nix
docker-manifest = mkDockerManifest {
  github = {
    enable = true;
    token = "$GH_TOKEN";
  };
  version = builtins.getEnv "VERSION";
  imageStreams = with self.packages; [x86_64-linux.docker aarch64-linux.docker];
}
```

> [!warning]
> Reading environment variables requires the `--impure` flag (e.g., `nix run --impure .#docker-manifest`).
> Do not use `builtins.getEnv` to read secrets, as this would expose them in the Nix store and could lead to uploading them to binary caches.
> For tokens/password, pass the name of the environment variable instead.

Here is a complete example for a GitHub action that is able to build an image for multiple architectures:

```yaml
on:
  push:
    branches: [main]
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
        with:
          platforms: arm64
      - uses: DeterminateSystems/nix-installer-action@v6
        with:
          extra-conf: |
            extra-platforms = aarch64-linux
      - uses: DeterminateSystems/magic-nix-cache-action@v2
      - run: nix run --impure .#docker-manifest
        env:
          VERSION: "1.0.0"
          GH_TOKEN: ${{ github.token }}
```

## Advanced

This repo uses the [nix-systems pattern](https://github.com/nix-systems/nix-systems), making it externally extensible.
