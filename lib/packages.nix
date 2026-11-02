lib:
let
  mapUpdateScript =
    f: pkg:
    pkg.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        updateScript = f (old.passthru.updateScript or null);
      };
    });
in
{
  /**
    Remove the update script of a package,
    e.g. one inherited from a nixpkgs package that would edit the nixpkgs sources.

    # Inputs

    `pkg`
    : The package to remove the update script from.

    # Type

    ```
    disableUpdateScript :: Derivation -> Derivation
    ```

    # Examples

    ```nix
    disableUpdateScript pkgs.hello
    => «derivation» with passthru.updateScript = null
    ```
  */
  disableUpdateScript = mapUpdateScript (_: null);

  /**
    Set the attribute path that `nix-update` resolves the package at.
    Naming where a package actually lives keeps `nix-update` from selecting it through a flattened set,
    which would force every package of that set just to answer one lookup.
    Packages without an update script are left unchanged.

    # Inputs

    `attrPath`
    : The attribute path of the package, separated by dots.

    `pkg`
    : The package to set the attribute path for.

    # Type

    ```
    setUpdateScriptAttrPath :: String -> Derivation -> Derivation
    ```

    # Examples

    ```nix
    setUpdateScriptAttrPath "vimPlugins.foo" pkgs.vimPlugins.foo
    => «derivation» with passthru.updateScript.attrPath = "vimPlugins.foo"
    ```
  */
  setUpdateScriptAttrPath =
    attrPath:
    mapUpdateScript (
      script:
      if script == null then
        null
      else if lib.isAttrs script && !lib.isDerivation script then
        script // { inherit attrPath; }
      else
        {
          command = script;
          inherit attrPath;
        }
    );

  /**
    Check if CI should build a derivation, following the `meta.hydraPlatforms` convention of Hydra.
    Without `meta.hydraPlatforms`, the derivation is built on its own system.

    # Inputs

    `drv`
    : The derivation to check.

    # Type

    ```
    isHydraTarget :: Derivation -> Bool
    ```

    # Examples

    ```nix
    isHydraTarget pkgs.hello
    => true
    isHydraTarget (pkgs.hello.overrideAttrs { meta.hydraPlatforms = [ ]; })
    => false
    ```
  */
  isHydraTarget = drv: lib.elem drv.system (drv.meta.hydraPlatforms or [ drv.system ]);
}
