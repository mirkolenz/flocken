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

Create a multi-arch image index from Nix-built images and push it to one or more registries.
The `images` can be archives (e.g., `dockerTools.buildLayeredImage`) or streams (e.g., `dockerTools.streamLayeredImage`).
All tags and registries share the same digest, which stays the same when a commit with reproducible images is published again.
String options may reference environment variables as `$VAR` or `\${VAR}` (escaped from Nix interpolation), which are expanded at runtime (`$$` for a literal `$`).
Use them for secrets (e.g., `"$GITHUB_TOKEN"`), as literal values end up in the Nix store.

```nix
docker-manifest = mkDockerManifest {
  github.enable = true;
  images = with self.packages; [ x86_64-linux.docker aarch64-linux.docker ];
};
```

With `github.enable`, the index is pushed to `ghcr.io` and annotated with the repository metadata from the payload of the event that triggered the workflow.
Events without a payload, such as `schedule`, lack the description, homepage, and license.

```yaml
on:
  push:
    branches: [main]
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v7
      - uses: docker/setup-qemu-action@v4
        with:
          platforms: arm64
      - uses: DeterminateSystems/nix-installer-action@v23
        with:
          extra-conf: extra-platforms = aarch64-linux
      - run: nix run .#docker-manifest
        env:
          VERSION: "1.0.0"
          GITHUB_TOKEN: ${{ github.token }}
```

### Signing with cosign

Set `cosign.enable = true` to sign the index with [cosign](https://github.com/sigstore/cosign).
Keyless signing in GitHub Actions additionally requires the `id-token: write` permission.
The index is signed in the first registry and copied with its signatures to the others.
Signatures can be verified as follows:

```bash
cosign verify \
  --certificate-identity https://github.com/OWNER/REPO/.github/workflows/WORKFLOW.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  REGISTRY/REPO:TAG
```
