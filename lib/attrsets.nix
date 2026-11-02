lib: {
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
  isEnabled = x: x.enable or false == true;

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
    attrs:
    lib.listToAttrs (
      lib.mapAttrsToListRecursive (path: lib.nameValuePair (lib.concatStringsSep "." path)) attrs
    );

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
}
