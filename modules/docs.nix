{ lib, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      mkDocs =
        {
          name,
          module,
          header,
        }:
        let
          eval = lib.evalModules {
            modules = [
              module
              (
                { lib, ... }:
                {
                  options._module.args = lib.mkOption { visible = false; };
                  config._module.check = false;
                }
              )
            ];
          };
          docs = pkgs.nixosOptionsDoc {
            inherit (eval) options;
            # remove /nix/store/* prefix
            transformOptions = opt: lib.removeAttrs opt [ "declarations" ];
          };
        in
        {
          inherit name;
          path = pkgs.runCommand name { } ''
            sed '1s/^/# ${header}\n\n/' ${docs.optionsCommonMark} > $out
            ${lib.getExe pkgs.comrak} --inplace $out
          '';
        };
    in
    {
      apps.docs.program = pkgs.writeShellApplication {
        name = "docs";
        text = ''
          mkdir -p ./docs
          cp -f ${config.packages.docs}/*.md ./docs
        '';
      };
      packages = {
        docs = pkgs.linkFarm "docs" (
          map mkDocs [
            {
              name = "docker-manifest.md";
              module = ../src/docker-manifest/module.nix;
              header = "`flocken.legacyPackages.\${system}.mkDockerManifest`";
            }
          ]
        );
      };
    };
}
