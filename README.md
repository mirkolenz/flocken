# Flocken

Flocken (German for "flakes") is a collection of utilities for nix flakes.

## Usage

The project supports semantic versioning, so we advise to pin the major version (e.g., `v1`) to avoid breaking changes.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flocken = {
      url = "github:mirkolenz/flocken/v1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {nixpkgs, flocken, ...}:  {};
}
```

Flocken currently provides the following attributes:

### [`flocken.legacyPackages.${system}.mkDockerManifest`](./src/docker-manifest.nix)

Create and push a Docker manifest to a registry.
This is particularly useful for multi-arch images.
The function takes the following attrset as an argument:

- `images`: List of Docker images to be added to the manifest. Can for instance be produced using `dockerTools.buildLayeredImage`. _Note:_ This should be a list of identical images for different architectures.
- `names`: List of fully qualified names of the docker image (e.g. `ghcr.io/mirkolenz/flocken`).
- `name`: Fully qualified name of the docker image (e.g. `ghcr.io/mirkolenz/flocken`). Merged with `names` if provided.
- `branch`: Name of the git branch (e.g. `main`) that is added to the list of tags.
- `latest`: Boolean indicating whether the `latest` tag should be added to the list of tags. If branch is `main` or `master`, this is set to `true` by default.
- `version`: Semantic version of the image (e.g. `v1.0.0` or `1.0.0`). The version as well as its major and minor components (`1.0` and `1`) are added to the list of tags.
- `extraTags`: List of additional tags to be added to the manifest.
- `annotations`: List of annotations to be added to the manifest.

Some arguments (e.g., `version`) differ between invocations and thus need to be provided in a dynamic fashion.
We recommend to use environment variables for this purpose.
For instance, when running in a GitHub action, you only have to provide a value for `VERSION` and then can use the following snippet:

```nix
dockerManifest = mkDockerManifest {
  branch = builtins.getEnv "GITHUB_REF_NAME";
  name = "ghcr.io/" + builtins.getEnv "GITHUB_REPOSITORY";
  version = builtins.getEnv "VERSION";
  images = with self.packages; [x86_64-linux.dockerImage aarch64-linux.dockerImage];
}
```

> [!warning]
> Reading environment variables requires the `--impure` flag (e.g., `nix run --impure .#dockerManifest`).

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
      - uses: DeterminateSystems/nix-installer-action@v4
        with:
          extra-conf: |
            extra-platforms = aarch64-linux
      - uses: DeterminateSystems/magic-nix-cache-action@v2
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ github.token }}
      - run: nix run --impure .#dockerManifest
        env:
          VERSION: ${{ steps.semanticrelease.outputs.version }}
```

## Advanced

This repo uses the [nix-systems pattern](https://github.com/nix-systems/nix-systems), making it externally extensible.
