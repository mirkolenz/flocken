{ self, lib, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      mkDocs =
        { module, header }:
        let
          eval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
            system = null;
            baseModules = [ ];
            modules = [
              module
              (
                { lib, ... }:
                {
                  options._module.args = lib.mkOption { visible = false; };
                }
              )
            ];
          };
          docs = pkgs.nixosOptionsDoc {
            inherit (eval) options;
          };
        in
        pkgs.runCommand "docs" { } ''
          mkdir -p $out
          substitute ${docs.optionsCommonMark} $out/docs.md \
            --replace-fail "file://${self.outPath}" "https://github.com/mirkolenz/flocken/blob/main" \
            --replace-fail "${self.outPath}" "flocken"
          sed -i '1s/^/# ${header}\n\n/' $out/docs.md
          ${lib.getExe pkgs.nodePackages.prettier} --write $out/docs.md
        '';
    in
    {
      apps.docs.program = pkgs.writeShellApplication {
        name = "docs";
        text = ''
          cp ${config.packages.docker-manifest-docs}/docs.md ./docker-manifest/docs.md
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
