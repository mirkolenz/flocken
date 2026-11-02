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

The builders of `flocken.legacyPackages.${system}` are also available through `flocken.overlays.default`, which builds them from your nixpkgs and makes them available to `callPackage`.

## [`flocken.lib`](https://mirkolenz.github.io/flocken/lib.html)

A collection of utility functions for nix flakes.
See the documentation for more details.

## `flocken.flakeModules`

Modules for [flake-parts](https://flake.parts).

- `evalChecks` adds a check `eval-<class>-<name>` for every configuration in `nixosConfigurations`, `darwinConfigurations`, and `homeConfigurations`.
  It forces the full evaluation of the configuration without building it, which `nix flake check` alone does not.
  Further derivations can be added through `evalTargets.<class>.<name>`, and `evalTargets.<class>.<name>.enable = false` skips one.
  Setting `evalTargets.<class>.<name>.system` explicitly avoids evaluating the configuration's pkgs to find it.
- `lib` declares `flake.lib` as a lazy attribute set, so several modules can add helpers to it.

```nix
flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [
    flocken.flakeModules.evalChecks
    flocken.flakeModules.lib
  ];
}
```

## `flocken.legacyPackages.${system}.mkGitHubBinary`

Install binaries from the release assets of a GitHub repository.
The release is pinned in a JSON file that the update script (`passthru.updateScript`) refreshes.
`assets` maps each system to one or more asset names, or is a function of the version returning such a mapping.

```nix
mkGitHubBinary {
  owner = "astral-sh";
  repo = "uv";
  file = ./release.json;
  binaries = [ "uv" "uvx" ];
  assets = {
    x86_64-linux = "uv-x86_64-unknown-linux-gnu.tar.gz";
    aarch64-darwin = "uv-aarch64-apple-darwin.tar.gz";
  };
}
```

## `flocken.legacyPackages.${system}.mkDarwinApp`

Install a macOS app bundle to `$out/Applications`, optionally wrapping an `executable` inside it as `$out/bin/${pname}`.
Combine it with `mkGitHubBinary.override { constructDrv = mkDarwinApp; }` to install apps from GitHub releases.

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

### GitLab CI/CD

With `gitlab.enable`, the index is pushed to the project's container registry and annotated with the project metadata from the predefined variables of GitLab CI/CD.
GitLab does not expose the license or homepage of a project without its API, so set these annotations explicitly if needed.

```yaml
release:
  image: nixos/nix
  script:
    - nix run .#docker-manifest
  variables:
    VERSION: "1.0.0"
```

### Signing with cosign

Set `cosign.enable = true` to sign the index with [cosign](https://github.com/sigstore/cosign).
Keyless signing in GitHub Actions additionally requires the `id-token: write` permission.
In GitLab CI/CD, it requires an ID token with the `sigstore` audience, which is only accepted by the public Sigstore instance for GitLab.com:

```yaml
release:
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
```

The index is signed in the first registry and copied with its signatures to the others.
Signatures can be verified as follows:

```bash
cosign verify \
  --certificate-identity https://github.com/OWNER/REPO/.github/workflows/WORKFLOW.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  REGISTRY/REPO:TAG
```

For GitLab, the identity is `https://gitlab.com/GROUP/PROJECT//.gitlab-ci.yml@refs/heads/main` and the issuer is `https://gitlab.com`.
