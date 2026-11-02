{
  lib,
  stdenvNoCC,
  mdbook,
  nixdoc,
  writeShellApplication,
  writeText,
  python3,
  optionsMarkdown,
}:
let
  libPages = map (lib.removeSuffix ".nix") (lib.remove "default.nix" (lib.attrNames (lib.readDir ../lib)));
  summary = writeText "SUMMARY.md" ''
    # Summary

    [Introduction](README.md)

    - [lib](lib.md)
    ${lib.concatMapStrings (name: "  - [${name}](lib/${name}.md)\n") libPages}- [mkDockerManifest](docker-manifest.md)
  '';
in
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
    cp ${summary} src/SUMMARY.md
    ln -s ${../README.md} src/README.md
    mkdir src/lib

    for name in ${toString libPages}; do
      {
        echo "# $name"
        echo
        nixdoc --category "" --description "" --prefix "" --file "${../lib}/$name.nix"
      } > "src/lib/$name.md"
    done

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
