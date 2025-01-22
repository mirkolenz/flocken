{ self, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      packages = {
        inherit (pkgs.dockerTools.examples) nginx nginxStream;
      };
      checks = {
        docker-manifest = config.legacyPackages.mkDockerManifest {
          branch = "main";
          imageFiles = with self.packages; [ x86_64-linux.nginx ];
          imageStreams = with self.packages; [ aarch64-linux.nginxStream ];
          registries."docker-manifest-dummy.mirkolenz.com" = {
            username = "test";
            password = "test";
            repo = "test";
          };
        };
        docker-manifest-github = config.legacyPackages.mkDockerManifest {
          github = {
            enable = true;
            repo = "mirkolenz/flocken";
            actor = "mirkolenz";
          };
          branch = "main";
          version = "1.0.0";
          imageFiles = with self.packages; [ x86_64-linux.nginx ];
          imageStreams = with self.packages; [ aarch64-linux.nginxStream ];
        };
      };
    };
}
