{ lib, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      mkOptions = pkgs.callPackage ../docs/options.nix { };
      mkOptionLinks = lib.mapAttrsToList (
        name: value: {
          name = "${name}.md";
          path = mkOptions value;
        }
      );
    in
    {
      packages = {
        optionsMarkdown = pkgs.linkFarm "options-markdown" (mkOptionLinks {
          docker-manifest = ../src/docker-manifest/module.nix;
        });
        book = pkgs.callPackage ../docs/book.nix {
          inherit (config.packages) optionsMarkdown;
        };
        docs = config.packages.book;
      };
    };
}
