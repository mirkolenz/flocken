{ lib, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      mkDocs =
        { module, header }:
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
            # hide /nix/store/* prefix
            transformOptions = opt: opt // { declarations = [ ]; };
          };
        in
        pkgs.runCommand "docs.md" { } ''
          sed '1s/^/# ${header}\n\n/' ${docs.optionsCommonMark} > $out
          ${lib.getExe pkgs.nodePackages.prettier} --write $out
        '';
    in
    {
      apps.docs.program = pkgs.writeShellApplication {
        name = "docs";
        text = ''
          cp -f ${config.packages.docker-manifest-docs} ./docker-manifest/docs.md
        '';
      };
      packages = {
        docker-manifest-docs = mkDocs {
          module = ./docker-manifest/module.nix;
          header = "`flocken.legacyPackages.\${system}.mkDockerManifest`";
        };
      };
    };
}
