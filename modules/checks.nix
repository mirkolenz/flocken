{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      checks = {
        docker-manifest = config.legacyPackages.mkDockerManifest {
          github = {
            enable = true;
            repo = "mirkolenz/flocken";
            actor = "mirkolenz";
            token = "$GH_TOKEN";
          };
          branch = "main";
          version = "1.0.0";
          imageFiles = with pkgs.dockerTools.examples; [
            nginx
          ];
          imageStreams = with pkgs.dockerTools.examples; [
            nginxStream
          ];
        };
      };
    };
}
