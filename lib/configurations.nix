lib: rec {
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
    map (x: x.key) (
      lib.importJSON (
        builtins.fetchurl {
          inherit sha256;
          url = "https://api.github.com/users/${user}/keys";
        }
      )
    );

  /**
    Get the path of the nix daemon socket after symlink resolution, e.g. for sandbox profiles.
    Upstream Nix uses the default socket on every platform.
    On darwin, Determinate Nix links the default socket to `/var/run/nix-daemon.socket`,
    which the `/var` firmlink resolves to `/private/var/run`.

    # Inputs

    `stdenv`
    : The stdenv of the host platform.

    `determinate`
    : Whether the host runs Determinate Nix, defaults to `false`.

    # Type

    ```
    nixDaemonSocket :: { stdenv: Stdenv, determinate: Bool } -> String
    ```

    # Examples

    ```nix
    nixDaemonSocket { inherit (pkgs) stdenv; }
    => "/nix/var/nix/daemon-socket/socket"
    nixDaemonSocket {
      inherit (pkgs) stdenv;
      determinate = true;
    }
    => "/private/var/run/nix-daemon.socket" # on darwin
    ```
  */
  nixDaemonSocket =
    {
      stdenv,
      determinate ? false,
    }:
    if determinate && stdenv.hostPlatform.isDarwin then
      "/private/var/run/nix-daemon.socket"
    else
      "/nix/var/nix/daemon-socket/socket";

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
