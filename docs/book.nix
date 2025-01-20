{
  lib,
  stdenvNoCC,
  mdbook,
  writeShellApplication,
  python3,
  dockerManifestMarkdown,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  name = "book";
  nativeBuildInputs = [ mdbook ];
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./book.toml
      ./src
    ];
  };
  buildPhase = ''
    runHook preBuild

    ln -s ${dockerManifestMarkdown} src/docker-manifest.md
    ln -s ${../README.md} src/README.md
    mdbook build

    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall

    mv book $out

    runHook postInstall
  '';
  passthru.serve = writeShellApplication {
    name = "serve";
    runtimeInputs = [ python3 ];
    text = ''
      python -m http.server \
        --bind 127.0.0.1 \
        --directory ${finalAttrs.finalPackage}
    '';
  };
})
