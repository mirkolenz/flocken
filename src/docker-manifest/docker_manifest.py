"""Create, push, and sign a multi-architecture Docker manifest.

The configuration is read from the JSON file given as the only argument.
Its strings may reference environment variables as `$VAR` or `${VAR}`,
which are expanded at runtime to their value or an empty string if unset.
A literal dollar sign is written as `$$`.
"""

import base64
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
from collections import defaultdict
from collections.abc import Iterator, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime
from functools import partial
from pathlib import Path
from string import Template
from typing import Final, Literal, TypedDict

type Json = str | int | float | bool | None | list[Json] | dict[str, Json]


class AutoTags(TypedDict):
    """The tags that are derived from the branch and version."""

    branch: bool
    latest: bool
    version: bool
    majorMinor: bool
    major: bool


class Registry(TypedDict):
    """A registry that the index is pushed to."""

    enable: bool
    name: str
    repo: str
    username: str
    password: str
    tls: Literal["enabled", "insecure", "disabled"]


class GitHub(TypedDict):
    """The settings of the GitHub integration."""

    enable: bool
    repo: str


class Cosign(TypedDict):
    """The settings for signing the index."""

    enable: bool
    recursive: bool
    key: str | None
    extraArgs: list[str]


class Config(TypedDict):
    """The config written by `mkDockerManifest`."""

    images: list[str]
    version: str
    branch: str | None
    defaultBranch: str | None
    tags: list[str]
    autoTags: AutoTags
    registries: dict[str, Registry]
    annotations: dict[str, Json]
    github: GitHub
    format: Literal["oci", "v2s2"]
    compression: Literal["gzip", "zstd"] | None
    cosign: Cosign


@dataclass(frozen=True, slots=True)
class Context:
    """The branches and annotations provided by the CI environment."""

    branch: str = ""
    default_branch: str = ""
    annotations: dict[str, Json] = field(default_factory=dict)


class License(TypedDict):
    """The license of a GitHub repository."""

    spdx_id: str


class Repository(TypedDict, total=False):
    """The repository metadata of a GitHub event payload."""

    description: str | None
    homepage: str | None
    default_branch: str
    license: License | None


# go-containerregistry, as used by cosign, looks up Docker Hub by its legacy key.
DOCKER_HUB: Final = {"docker.io", "index.docker.io"}
DOCKER_HUB_KEY: Final = "https://index.docker.io/v1/"
# The flag of `regctl image mod` and the index media type for each format.
FORMATS: Final = {
    "oci": ("--to-oci", "application/vnd.oci.image.index.v1+json"),
    "v2s2": (
        "--to-docker",
        "application/vnd.docker.distribution.manifest.list.v2+json",
    ),
}
# The cosign flag needed to reach a registry with the given TLS setting.
COSIGN_TLS: Final = {
    "enabled": [],
    "insecure": ["--allow-insecure-registry"],
    "disabled": ["--allow-http-registry"],
}
# Tags may only contain ASCII word characters, periods, and dashes.
TAG_INVALID: Final = re.compile(r"[^\w.-]", re.ASCII)


def expand(value: Json) -> Json:
    """Replace environment variable references in strings and lists of strings.

    Objects are left untouched, as `load` expands them while parsing.

    >>> os.environ["FLOCKEN_TEST"] = "1.0.0"
    >>> expand(["v$FLOCKEN_TEST", "${FLOCKEN_TEST}", "$FLOCKEN_UNSET", "pa$$word"])
    ['v1.0.0', '1.0.0', '', 'pa$word']
    """
    match value:
        case str():
            return Template(value).safe_substitute(defaultdict(str, os.environ))
        case list():
            return [expand(item) for item in value]
        case _:
            return value


def load(path: Path) -> Config:
    """Parse the config file and expand environment variables in all values."""
    return json.loads(
        path.read_text(),
        object_hook=lambda obj: {key: expand(value) for key, value in obj.items()},
    )


def flatten(value: Json, prefix: str = "") -> Iterator[tuple[str, str]]:
    """Flatten nested annotations to dotted keys, skipping empty values.

    >>> dict(flatten({"org": {"oci": {"title": "flocken", "url": ""}}, "x": 1}))
    {'org.oci.title': 'flocken', 'x': '1'}
    """
    if isinstance(value, dict):
        for key, child in value.items():
            yield from flatten(child, f"{prefix}.{key}" if prefix else key)

    elif value is not None and value != "":
        yield prefix, value if isinstance(value, str) else json.dumps(value)


def sanitize_tag(value: str) -> str:
    """Replace the characters that are invalid in tags and trim the result to a valid tag.

    >>> sanitize_tag(".feature/ü")
    'feature--'
    """
    return TAG_INVALID.sub("-", value).lstrip(".-")[:128]


def make_tags(
    auto: AutoTags,
    custom: Sequence[str],
    version: str,
    branch: str,
    default_branch: str,
) -> list[str]:
    """Combine the automatic and custom tags without duplicates.

    >>> auto = AutoTags(
    ...     branch=True, latest=True, version=True, majorMinor=True, major=True
    ... )
    >>> make_tags(auto, ["custom"], "1.2.3", "main", "main")
    ['main', 'latest', '1.2.3', '1.2', '1', 'custom']
    >>> make_tags(auto, [], "1.2.3-rc.1", "feature/ü", "main")
    ['feature--', '1.2.3-rc.1']
    >>> make_tags(auto, [], "1.2.3+build.5", "", "main")
    ['1.2.3-build.5', '1.2', '1']
    """
    # Pre-releases, marked by a dash, get no major and minor tags.
    release = re.fullmatch(
        r"(?P<major>\d+)\.(?P<minor>\d+)(\.\d+)?(\+[\w.-]*)?", version, re.ASCII
    )
    tags = [
        sanitize_tag(branch) if auto["branch"] else "",
        "latest" if auto["latest"] and branch == default_branch else "",
        sanitize_tag(version) if auto["version"] else "",
        ".".join(release.group("major", "minor"))
        if auto["majorMinor"] and release
        else "",
        release["major"] if auto["major"] and release else "",
        *custom,
    ]

    return list(dict.fromkeys(tag for tag in tags if tag))


def load_repository() -> Repository:
    """Load the repository metadata from the payload of the GitHub Actions event.

    Events without a payload, such as `schedule`, yield no metadata.
    """
    path = os.environ.get("GITHUB_EVENT_PATH")

    return json.loads(Path(path).read_text()).get("repository", {}) if path else {}


def forge_annotations(
    server: str, repo: str, title: str | None = None
) -> dict[str, Json]:
    """Derive the OCI annotations shared by all forges from the server and repository path.

    >>> forge_annotations("https://github.com", "mirkolenz/flocken")["vendor"]
    'mirkolenz'
    """
    namespace, _, name = repo.rpartition("/")

    # https://github.com/opencontainers/image-spec/blob/main/annotations.md
    return {
        "authors": f"{server}/{namespace}",
        "source": f"{server}/{repo}",
        "vendor": namespace,
        "title": title or name,
    }


def github_context(github: GitHub) -> Context:
    """Read the context of a GitHub Actions workflow from its environment and event payload."""
    if not github["repo"]:
        sys.exit("`github.repo` must be set when `github.enable` is true")

    env = os.environ
    repository = load_repository()
    license = repository.get("license")
    on_branch = env.get("GITHUB_REF_TYPE") == "branch"

    return Context(
        branch=env.get("GITHUB_REF_NAME", "") if on_branch else "",
        # Events without a payload, such as `schedule`, run on the default branch.
        default_branch=repository.get("default_branch")
        or env.get("GITHUB_REF_NAME", ""),
        annotations=forge_annotations(
            env.get("GITHUB_SERVER_URL", "https://github.com"), github["repo"]
        )
        | {
            "url": repository.get("homepage"),
            "licenses": license["spdx_id"] if license else None,
            "description": repository.get("description"),
            "revision": env.get("GITHUB_SHA"),
        },
    )


def git(*args: str) -> str | None:
    """Query the git repository in the working directory, returning None if that fails."""
    try:
        output = subprocess.check_output(
            ["git", *args], text=True, stderr=subprocess.DEVNULL
        )
    except (OSError, subprocess.CalledProcessError):
        return None

    return output.strip() or None


def local_context() -> Context:
    """Read the branch and revision from the git repository, as no CI provides them."""
    return Context(
        # Empty if the HEAD is detached.
        branch=git("branch", "--show-current") or "",
        annotations={"revision": git("rev-parse", "HEAD")},
    )


def describe(config: Config) -> tuple[list[str], dict[str, str]]:
    """Derive the tags and annotations, using the CI environment if an integration is enabled."""
    github = config["github"]
    context = github_context(github) if github["enable"] else local_context()

    version = config["version"].removeprefix("v")
    branch = context.branch if config["branch"] is None else config["branch"]
    default_branch = config["defaultBranch"] or context.default_branch or "main"
    tags = make_tags(
        config["autoTags"], config["tags"], version, branch, default_branch
    )

    if not tags:
        sys.exit("At least one `tag` must be set")

    oci_annotations: dict[str, Json] = {
        # The commit time keeps the digest stable when a commit is published again.
        "created": git("log", "-1", "--format=%cI")
        or datetime.now().astimezone().isoformat(timespec="seconds"),
        "version": version,
    } | context.annotations
    annotations = dict(flatten(oci_annotations, "org.opencontainers.image"))
    annotations.update(flatten(config["annotations"]))

    return tags, annotations


def run(*args: str) -> str:
    """Run a command after echoing it like `set -x` and return its output."""
    print("+", shlex.join(args), file=sys.stderr, flush=True)

    return subprocess.check_output(args, text=True).strip()


def write_auth(registries: Sequence[Registry], path: Path) -> None:
    """Write the credentials as Docker config, which regctl and cosign both read."""
    auths = {
        DOCKER_HUB_KEY if registry["name"] in DOCKER_HUB else registry["name"]: {
            "auth": base64.b64encode(
                f"{registry['username']}:{registry['password']}".encode()
            ).decode()
        }
        for registry in registries
        if registry["username"]
    }
    path.write_text(json.dumps({"auths": auths}))


def import_image(image: Path, ref: str, tmp: Path) -> None:
    """Import an image archive or stream (an executable printing the archive)."""
    archive = image

    if os.access(image, os.X_OK):
        archive = tmp / f"{image.name}.tar"
        print("+", image, ">", archive, file=sys.stderr, flush=True)

        with archive.open("wb") as file:
            try:
                subprocess.run([image], stdout=file, check=True)
            except OSError as error:
                sys.exit(
                    f"Cannot run the image stream {image} on this platform, use an archive instead: {error}"
                )

    run("regctl", "image", "import", ref, str(archive))

    if archive != image:
        archive.unlink()


def build_index(config: Config, annotations: Mapping[str, str], tmp: Path) -> str:
    """Assemble the index in a local OCI layout and return its reference."""
    compression = config["compression"]
    convert, media_type = FORMATS[config["format"]]
    annotation_args = [
        f"--annotation={key}={value}" for key, value in annotations.items()
    ]
    layout = f"ocidir://{tmp / 'layout'}"
    refs = [f"{layout}:{position}" for position in range(len(config["images"]))]

    for image, ref in zip(config["images"], refs, strict=True):
        import_image(Path(image), ref, tmp)
        run(
            "regctl",
            "image",
            "mod",
            ref,
            "--replace",
            convert,
            *(["--layer-compress", compression] if compression else []),
            *annotation_args,
        )

    index = f"{layout}:index"
    run(
        "regctl",
        "index",
        "create",
        index,
        f"--media-type={media_type}",
        *annotation_args,
        *(f"--ref={ref}" for ref in refs),
    )

    return index


def main(config: Config) -> None:
    """Create, push, and sign the image index described by the config."""
    registries = [
        registry for registry in config["registries"].values() if registry["enable"]
    ]

    if not registries:
        sys.exit("At least one `registry` must be set")

    for key, registry in config["registries"].items():
        if not registry["enable"]:
            continue

        if not (registry["name"] and registry["repo"]):
            sys.exit(f'`registries."{key}"` needs a non-empty `name` and `repo`')

        # Usually an unset environment variable, which would otherwise cause an opaque auth error.
        if bool(registry["username"]) != bool(registry["password"]):
            sys.exit(
                f'`registries."{key}"` needs both or neither of `username` and `password`'
            )

    tags, annotations = describe(config)
    cosign = config["cosign"]
    # Repository names must be lowercase, unlike the names of GitHub repositories.
    repos = [
        f"{registry['name']}/{registry['repo'].lower()}" for registry in registries
    ]
    copy = partial(
        run,
        "regctl",
        *(
            f"--host=reg={registry['name']},tls={registry['tls']}"
            for registry in registries
        ),
        "image",
        "copy",
    )

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        # Isolate the credentials and settings from the user's configuration.
        os.environ["DOCKER_CONFIG"] = tmpdir
        os.environ["REGCTL_CONFIG"] = str(tmp / "regctl.json")
        write_auth(registries, tmp / "config.json")
        # The index is copied to every tag, so all tags and registries share its digest.
        index = build_index(config, annotations, tmp)
        digest = run("regctl", "image", "digest", index)
        print(run("regctl", "manifest", "get", index))
        print(f"Digest: {digest}")
        print(f"Registries: {' '.join(registry['name'] for registry in registries)}")
        print(f"Tags: {' '.join(tags)}", flush=True)

        # The images are uploaded once per registry, the other tags only reference the digest.
        for repo in repos:
            copy(index, f"{repo}:{tags[0]}")

            for tag in tags[1:]:
                copy(f"{repo}@{digest}", f"{repo}:{tag}")

        if cosign["enable"]:
            primary, *mirrors = repos
            run(
                "cosign",
                "sign",
                "--yes",
                *(["--recursive"] if cosign["recursive"] else []),
                *(["--key", cosign["key"]] if cosign["key"] else []),
                *COSIGN_TLS[registries[0]["tls"]],
                *cosign["extraArgs"],
                f"{primary}@{digest}",
            )

            # The mirrors already have the index, so only the signatures are copied.
            for mirror in mirrors:
                copy(
                    "--referrers",
                    "--digest-tags",
                    f"{primary}@{digest}",
                    f"{mirror}@{digest}",
                )


if __name__ == "__main__":
    match sys.argv:
        case [_, path]:
            try:
                main(load(Path(path)))
            except subprocess.CalledProcessError as error:
                sys.exit(
                    f"Command failed with exit code {error.returncode}: {shlex.join(map(str, error.cmd))}"
                )
        case _:
            sys.exit("Usage: docker-manifest CONFIG")
