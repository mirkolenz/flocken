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

## [`flocken.lib`](https://mirkolenz.github.io/flocken/lib.html)

A collection of utility functions for nix flakes.
See the documentation for more details.

## [`flocken.legacyPackages.${system}.mkDockerManifest`](https://mirkolenz.github.io/flocken/docker-manifest.html)

Create and push a Docker manifest to a registry.
This is particularly useful for multi-arch images.
Some arguments (e.g., `version`) differ between invocations and thus need to be provided in a dynamic fashion.
We recommend to use environment variables for this purpose.
For instance, when running in a GitHub action, you only have to provide a value for `VERSION` and `GITHUB_TOKEN` and then can use the following snippet:

```nix
docker-manifest = mkDockerManifest {
  github = {
    enable = true;
    token = "$GITHUB_TOKEN";
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
          GITHUB_TOKEN: ${{ github.token }}
```

### Signing with cosign

Set `cosign.enable = true` to sign the pushed manifest with [cosign](https://github.com/sigstore/cosign).
For keyless signing in GitHub Actions, two things are not obvious:

1. The workflow job needs `id-token: write` in addition to `packages: write`, otherwise cosign cannot obtain an OIDC token and the run fails by design.
2. cosign reuses the credentials that crane already wrote to the Docker config, so no extra login step is needed.

```yaml
    permissions:
      contents: write
      packages: write
      id-token: write
```

Signatures produced with keyless signing can be verified as follows:

```bash
cosign verify \
  --certificate-identity https://github.com/OWNER/REPO/.github/workflows/WORKFLOW.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  REGISTRY/REPO:TAG
```
