{
  lib,
  stdenvNoCC,
  mdbook,
  nixdoc,
  writeShellApplication,
  python3,
  optionsMarkdown,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  name = "book";
  nativeBuildInputs = [
    mdbook
    nixdoc
  ];
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./book.toml
      ./src
    ];
  };
  buildPhase = ''
    runHook preBuild

    cp ${optionsMarkdown}/*.md src
    ln -s ${../README.md} src/README.md
    nixdoc \
      --category "" \
      --description "" \
      --prefix "" \
      --file ${../lib/default.nix} > src/lib.md
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
