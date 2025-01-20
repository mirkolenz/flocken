{
  lib,
  pkgs,
  module,
  ...
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
    # hide /nix/store/* prefix
    transformOptions = opt: lib.removeAttrs opt [ "declarations" ];
  };
in
docs.optionsCommonMark
