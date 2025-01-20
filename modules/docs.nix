{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      packages = {
        dockerManifestMarkdown = pkgs.callPackage ../docs/options.nix {
          module = ../src/docker-manifest/module.nix;
        };
        book = pkgs.callPackage ../docs/book.nix {
          inherit (config.packages) dockerManifestMarkdown;
        };
        docs = config.packages.book;
      };
    };
}
