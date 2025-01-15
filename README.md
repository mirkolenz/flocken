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

### [`flocken.legacyPackages.${system}.mkDockerManifest`](./docker-manifest/default.md)

Create and push a Docker manifest to a registry.
This is particularly useful for multi-arch images.
An overview of the configuration options is available in the [module definition](./docker-manifest/module.nix).
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
