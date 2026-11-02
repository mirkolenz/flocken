lib: rec {
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
