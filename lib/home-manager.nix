lib: rec {
  /**
    Create a home-manager activation entry that installs writable copies of files after `linkGeneration`.
    Useful for programs that rewrite their own config and fail on read-only store symlinks.
    The declared content is restored on every activation.

    # Inputs

    `config`
    : The home-manager configuration.

    `files`
    : A list of `{ source, target, mode ? "600" }` attrsets.

    # Type

    ```
    mkMutableFiles :: { config: AttrSet, files: [ { source: Path, target: String, mode: String } ] } -> DagEntry
    ```

    # Examples

    ```nix
    home.activation.zedSettings = mkMutableFiles {
      inherit config;
      files = [
        {
          source = settingsFile;
          target = "${config.xdg.configHome}/zed/settings.json";
        }
      ];
    };
    ```
  */
  mkMutableFiles =
    { config, files }:
    config.lib.dag.entryAfter [ "linkGeneration" ] (
      lib.concatMapStringsSep "\n" (
        {
          source,
          target,
          mode ? "600",
        }:
        "run install -Dm${mode} $VERBOSE_ARG ${lib.escapeShellArg source} ${lib.escapeShellArg target}"
      ) files
    );

  /**
    Like `mkMutableFiles`, but for a single file.

    # Inputs

    `config`
    : The home-manager configuration.

    `source`
    : The file to copy.

    `target`
    : The absolute path of the writable copy.

    `mode`
    : The file mode of the copy, defaults to `600`.

    # Type

    ```
    mkMutableFile :: { config: AttrSet, source: Path, target: String, mode: String } -> DagEntry
    ```

    # Examples

    ```nix
    home.activation.zedSettings = mkMutableFile {
      inherit config;
      source = settingsFile;
      target = "${config.xdg.configHome}/zed/settings.json";
    };
    ```
  */
  mkMutableFile =
    { config, ... }@file:
    mkMutableFiles {
      inherit config;
      files = [ (removeAttrs file [ "config" ]) ];
    };

  /**
    Create a home-manager activation entry that links a target to a local checkout,
    so edits take effect without a rebuild.
    Unlike `config.lib.file.mkOutOfStoreSymlink`, hosts without the checkout are skipped instead of getting a dangling link.

    # Inputs

    `config`
    : The home-manager configuration.

    `target`
    : The absolute path of the link.

    `checkout`
    : The absolute path of the checkout.

    # Type

    ```
    mkCheckoutLink :: { config: AttrSet, target: String, checkout: String } -> DagEntry
    ```

    # Examples

    ```nix
    home.activation.nvimConfig = mkCheckoutLink {
      inherit config;
      target = "${config.xdg.configHome}/nvim";
      checkout = "${config.home.homeDirectory}/projects/nvim-config";
    };
    ```
  */
  mkCheckoutLink =
    {
      config,
      target,
      checkout,
    }:
    config.lib.dag.entryAfter [ "linkGeneration" ] ''
      if [[ -e ${lib.escapeShellArg checkout} ]]; then
        run mkdir -p $VERBOSE_ARG ${lib.escapeShellArg (dirOf target)}
        run ln -sfn $VERBOSE_ARG ${lib.escapeShellArg checkout} ${lib.escapeShellArg target}
      fi
    '';
}
