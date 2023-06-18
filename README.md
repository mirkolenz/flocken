# Flocken

Flocken (German for "flakes") is a collection of utilities for nix flakes.

## Usage

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
- `branch`: Name of the git branch (e.g. `main`) that is added to the list of tags.
- `latest`: Boolean indicating whether the `latest` tag should be added to the list of tags. If branch is `main` or `master`, this is set to `true` by default.
- `version`: Semantic version of the image (e.g. `v1.0.0` or `1.0.0`). The version as well as its major and minor components (`1.0` and `1`) are added to the list of tags.
- `extraTags`: List of additional tags to be added to the manifest.
- `name` (deprecated): Fully qualified name of the docker image (e.g. `ghcr.io/mirkolenz/flocken`).

## Advanced

This repo uses the [nix-systems pattern](https://github.com/nix-systems/nix-systems), making it externally extensible.
