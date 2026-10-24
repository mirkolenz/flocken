{
  lib,
  writers,
  buildPackages,
  cosign,
  gitMinimal,
  python3Minimal,
  regclient,
}:
writers.makePythonWriter python3Minimal python3Minimal.pkgs buildPackages.python3Packages
  "/bin/docker-manifest"
  {
    # Black-style formatting breaks lines before binary operators.
    flakeIgnore = [
      "E501"
      "W503"
    ];
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [
        cosign
        gitMinimal
        regclient.regctl
      ])
    ];
  }
  ./docker_manifest.py
