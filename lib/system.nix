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
}
