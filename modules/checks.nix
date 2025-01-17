{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      checks = {
        docker-manifest = config.legacyPackages.mkDockerManifest {
          branch = "main";
          version = "1.0.0";
          imageFiles = with pkgs.dockerTools.examples; [ nginx ];
          imageStreams = with pkgs.dockerTools.examples; [ nginxStream ];
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
          imageFiles = with pkgs.dockerTools.examples; [ nginx ];
          imageStreams = with pkgs.dockerTools.examples; [ nginxStream ];
        };
      };
    };
}
