{ self, lib, ... }:
let
  images = with self.packages; [
    x86_64-linux.nginx
    aarch64-linux.nginxStream
  ];
in
{
  perSystem =
    { pkgs, config, ... }:
    {
      packages = {
        inherit (pkgs.dockerTools.examples) nginx nginxStream;
      };
      checks =
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          docker-manifest-test = pkgs.callPackage ../src/docker-manifest/test.nix {
            inherit (config.legacyPackages) mkDockerManifest;
          };
        }
        // {
          docker-manifest = config.legacyPackages.mkDockerManifest {
            inherit images;
            registries."docker-manifest-dummy.mirkolenz.com" = {
              username = "test";
              password = "test";
              repo = "test";
            };
          };
          docker-manifest-github = config.legacyPackages.mkDockerManifest {
            inherit images;
            github = {
              enable = true;
              repo = "mirkolenz/flocken";
            };
          };
        };
    };
}
