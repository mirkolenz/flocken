{
  imports = [
    ./checks.nix
    ./docs.nix
  ];
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;
    };
}
