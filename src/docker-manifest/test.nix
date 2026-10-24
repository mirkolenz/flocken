{
  lib,
  runCommand,
  apacheHttpd,
  cosign,
  distribution,
  gitMinimal,
  jq,
  python3Minimal,
  regclient,
  writers,
  dockerTools,
  mkDockerManifest,
}:
let
  # The index is pushed to and signed in the primary, then copied to the mirror.
  primary = "localhost:5000";
  mirror = "localhost:5001";
  mkRegistryConfig =
    registry:
    writers.writeYAML "registry.yml" {
      version = 0.1;
      storage.filesystem.rootdirectory = "/tmp/${registry}";
      http.addr = registry;
      auth.htpasswd = {
        realm = "test";
        path = "/tmp/htpasswd";
      };
    };
  # A subset of the payload of a `push` event.
  event = writers.writeJSON "event.json" {
    repository = {
      default_branch = "main";
      description = "Nix flake utilities";
      homepage = null;
      license.spdx_id = "MIT";
    };
  };
  docker-manifest = mkDockerManifest {
    images = with dockerTools.examples; [
      nginx
      nginxStream
    ];
    version = "v1.2.3";
    tags = [ "$EXTRA_TAG" ];
    annotations.org.opencontainers.image.title = "Flocken Test";
    github = {
      enable = true;
      repo = "mirkolenz/flocken";
    };
    registries =
      lib.genAttrs [ primary mirror ] (_: {
        repo = "flocken";
        username = "user";
        password = "$REGISTRY_PASSWORD";
        tls = "disabled";
      })
      // {
        "ghcr.io".enable = false;
      };
    cosign = {
      enable = true;
      key = "cosign.key";
      extraArgs = [
        "--use-signing-config=false"
        "--tlog-upload=false"
      ];
    };
  };
  githubEnv = {
    GITHUB_EVENT_PATH = event;
    GITHUB_REF_NAME = "main";
    GITHUB_REF_TYPE = "branch";
    GITHUB_SHA = "0123456789abcdef";
    EXTRA_TAG = "custom";
  };
  # Runs the program with the variables of a CI environment.
  withEnv =
    vars: program:
    "env ${
      lib.concatMapAttrsStringSep " " (name: value: "${name}=${lib.escapeShellArg value}") vars
    } ${lib.getExe program}";
in
runCommand "docker-manifest-test"
  {
    nativeBuildInputs = [
      apacheHttpd
      cosign
      distribution
      gitMinimal
      jq
      python3Minimal
      regclient.regctl
    ];
    env = {
      REGISTRY_PASSWORD = "secret";
      COSIGN_PASSWORD = "";
      GIT_COMMITTER_DATE = "2026-01-01T00:00:00Z";
    };
  }
  ''
    export HOME=$TMPDIR
    cp ${./docker_manifest.py} docker_manifest.py
    python3 -m doctest docker_manifest.py

    htpasswd -Bbc /tmp/htpasswd user "$REGISTRY_PASSWORD"
    registry serve ${mkRegistryConfig primary} 2> primary.log &
    registry serve ${mkRegistryConfig mirror} 2> mirror.log &

    for registry in ${primary} ${mirror}; do
      until (: < "/dev/tcp/''${registry%:*}/''${registry#*:}") 2> /dev/null; do
        sleep 0.1
      done
    done

    cosign generate-key-pair
    git init --quiet
    git -c user.name=test -c user.email=test@example.com commit --quiet --allow-empty --message init

    # Checks that all given tags of a repository point to the same digest.
    assert_tags() {
      local repo=$1 digest
      shift
      digest=$(regctl image digest "$repo:$1")

      for tag in "$@"; do
        [[ $(regctl image digest "$repo:$tag") == "$digest" ]]
      done
    }

    ${withEnv githubEnv docker-manifest}

    for registry in ${primary} ${mirror}; do
      regctl registry set $registry --tls disabled --skip-check
      cosign login $registry --username user --password "$REGISTRY_PASSWORD"
    done

    digest=$(regctl image digest ${primary}/flocken:main)

    for repo in ${primary}/flocken ${mirror}/flocken; do
      assert_tags $repo main latest 1.2.3 1.2 1 custom
      [[ $(regctl image digest $repo:main) == "$digest" ]]
      cosign verify --key cosign.pub --insecure-ignore-tlog --allow-http-registry $repo@$digest > /dev/null
    done

    # The archive and the stream contain the same image, which is deduplicated.
    regctl manifest get --format raw-body ${primary}/flocken:main | jq -e '
      (.manifests | length == 1)
      and .annotations["org.opencontainers.image.version"] == "1.2.3"
      and .annotations["org.opencontainers.image.title"] == "Flocken Test"
      and .annotations["org.opencontainers.image.description"] == "Nix flake utilities"
      and .annotations["org.opencontainers.image.licenses"] == "MIT"
      and .annotations["org.opencontainers.image.source"] == "https://github.com/mirkolenz/flocken"
      and .annotations["org.opencontainers.image.revision"] == "0123456789abcdef"
      and .annotations["org.opencontainers.image.created"] == "2026-01-01T00:00:00Z"
      and (.annotations | has("org.opencontainers.image.url") | not)
    '
    regctl manifest get --format raw-body ${primary}/flocken@$(regctl image digest --platform local ${primary}/flocken:main) | jq -e '
      .mediaType == "application/vnd.oci.image.manifest.v1+json"
      and .annotations["org.opencontainers.image.title"] == "Flocken Test"
      and all(.layers[]; .mediaType == "application/vnd.oci.image.layer.v1.tar+gzip")
    '

    touch $out
  ''
