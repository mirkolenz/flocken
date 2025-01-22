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
    let
      # Cannot use "${dir}/${name}" since that would return a string and not a path
      # dir + "/${name}" would be valid as well
      mkImport = name: dir + ("/" + name);
      filterPath =
        name: type:
        !lib.hasPrefix "_" name
        && (
          (type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
          || (type == "directory" && builtins.pathExists (mkImport "${name}/default.nix"))
        );
      dirContents = builtins.readDir dir;
      filteredContents = lib.filterAttrs filterPath dirContents;
      filteredPaths = builtins.attrNames filteredContents;
    in
    builtins.map mkImport filteredPaths;

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
  optionalPath = path: if builtins.pathExists path then [ path ] else [ ];

  /**
    Check if a value of arbitrary type is empty.

    # Inputs

    `value`
    : The value to check for emptiness.

    # Type

    ```
    isEmpty :: Any -> Bool
    ```

    # Examples

    ```nix
    isEmpty ""
    => true
    isEmpty null
    => true
    isEmpty [ ]
    => true
    isEmpty { }
    => true
    isEmpty "foo"
    => false
    isEmpty [ "foo" ]
    => false
    isEmpty { foo = "bar"; }
    => false
    ```
  */
  isEmpty = value: value == null || value == "" || value == [ ] || value == { };

  /**
    Check if a value of arbitrary type is non-empty.
    Opposite of `isEmpty`.

    # Inputs

    `value`
    : The value to check for non-emptiness.

    # Type

    ```
    isNotEmpty :: Any -> Bool
    ```

    # Examples

    ```nix
    isNotEmpty ""
    => false
    ```
  */
  isNotEmpty = value: !isEmpty value;

  /**
    Checks if an attrset has a key with the name `enable` set to `true`.

    # Inputs

    `x`
    : The attrset to check.

    # Type

    ```
    isEnabled :: { enable ? Bool } -> Bool
    ```

    # Examples

    ```nix
    isEnabled { enable = true; }
    => true
    isEnabled { enable = false; }
    => false
    isEnabled { }
    => false
    ```
  */
  isEnabled = x: builtins.hasAttr "enable" x && x.enable == true;

  /**
    Returns a list of GitHub SSH keys for a user.

    # Inputs

    `user`
    : The GitHub username to get the SSH keys for.

    `sha256`
    : The sha256 hash of the file.

    # Type

    ```
    githubSshKeys :: { user: String, sha256: String } -> [ String ]
    ```

    # Examples

    ```nix
    githubSshKeys {
      user = "mirkolenz";
      sha256 = lib.fakeSha256;
    }
    => [
      "ssh-rsa AAAA..."
      "ssh-rsa AAAA..."
    ]
    ```
  */
  githubSshKeys =
    {
      user,
      sha256,
    }:
    let
      apiResponse = builtins.fetchurl {
        inherit sha256;
        url = "https://api.github.com/users/${user}/keys";
      };
      parsedResponse = builtins.fromJSON (builtins.readFile apiResponse);
    in
    builtins.map (x: x.key) parsedResponse;

  /**
    Get all leaves of an attrset.

    # Inputs

    `attrs`
    : The attrset to get the leaves of.

    # Type

    ```
    getLeaves :: AttrSet -> AttrSet
    ```

    # Examples

    ```nix
    getLeaves {
      foo = {
        bar = "baz";
      };
    }
    => {
      "foo.bar" = "baz";
    }
    ```
  */
  getLeaves =
    let
      getLeavesPath =
        attrs: path:
        if builtins.isAttrs attrs then
          builtins.concatLists (lib.mapAttrsToList (key: value: getLeavesPath value (path ++ [ key ])) attrs)
        else
          [
            {
              name = builtins.concatStringsSep "." path;
              value = attrs;
            }
          ];
    in
    attrs: builtins.listToAttrs (getLeavesPath attrs [ ]);

  /**
    Return an attribute from nested attribute sets.

    # Inputs

    `path`
    : The path to the attribute.

    `default`
    : The default value to return if the attribute does not exist.

    `set`
    : The attribute set to get the attribute from.

    # Type

    ```
    attrByPath :: String -> Any -> AttrSet -> Any
    ```

    # Examples

    ```nix
    attrByPath "foo.bar" "default" { foo = { bar = "baz"; }; }
    => "baz"
    ```
  */
  attrByDottedPath = path: lib.attrByPath (lib.splitString "." path);

  /**
    Like `attrByDottedPath`, but without a default value.
    If it doesn't find the path it will throw an error.

    # Inputs

    `path`
    : The path to the attribute.

    `set`
    : The attribute set to get the attribute from.

    # Type

    ```
    getAttrFromDottedPath :: String -> AttrSet -> Any
    ```

    # Examples

    ```nix
    getAttrFromDottedPath "foo.bar" { foo = { bar = "baz"; }; }
    => "baz"
    ```
  */
  getAttrFromDottedPath = path: lib.getAttrFromPath (lib.splitString "." path);

  /**
    Create a new attribute set with value set at the nested attribute location specified in PATH.

    # Inputs

    `path`
    : The path to the attribute.

    `value`
    : The value to set.

    # Type

    ```
    setAttrByDottedPath :: String -> Any -> AttrSet
    ```

    # Examples

    ```nix
    setAttrByDottedPath "foo.bar" "baz"
    => { foo = { bar = "baz"; }; }
    ```
  */
  setAttrByDottedPath = path: lib.setAttrByPath (lib.splitString "." path);

  /**
    Return the value if the condition is true, otherwise return null.

    # Inputs

    `cond`
    : The condition to check.

    `value`
    : The value to return if the condition is true.

    # Type

    ```
    maybe :: Bool -> Any -> Any
    ```

    # Examples

    ```nix
    maybe true "foo"
    => "foo"
    maybe false "foo"
    => null
    ```
  */
  maybe = cond: value: if cond then value else null;
}
