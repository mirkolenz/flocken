lib: {
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
}
