lib: rec {
  /**
    Get all modules in a directory.
    Can for instance be used to automatically import all modules in a directory.
    Directories containing a `default.nix` file are considered modules.
    Paths starting with `_` are ignored.

    # Inputs

    `dir`
    : The directory to search for modules in.

    # Type

    ```
    getModules :: Path -> [ Path ]
    ```

    # Examples

    ```nix
    getModules ./.
    => [
      ./module1
      ./module2
    ]
    ```
  */
  getModules =
    dir:
    lib.pipe (lib.readDir dir) [
      (lib.filterAttrs (name: _: !lib.hasPrefix "_" name))
      (lib.filterAttrs (
        name: type:
        (type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
        || (type == "directory" && lib.pathExists (dir + "/${name}/default.nix"))
      ))
      lib.attrNames
      (map (name: dir + "/${name}"))
    ];

  /**
    Get a path as a list if it exists.
    Returns an empty list if the path does not exist.
    Useful for adding optional paths to import statements.

    # Inputs

    `path`
    : The path to check for existence.

    # Type

    ```
    optionalPath :: Path -> [ Path ]
    ```

    # Examples

    ```nix
    optionalPath ./module.nix
    => [ ./module.nix ]
    optionalPath ./non-existing-module.nix
    => [ ]
    ```
  */
  optionalPath = path: if lib.pathExists path then [ path ] else [ ];
}
