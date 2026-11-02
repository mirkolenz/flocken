lib: lib.mergeAttrsList (map (file: import file lib) ((import ./filesystem.nix lib).getModules ./.))
