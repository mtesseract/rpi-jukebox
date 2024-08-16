let
  nixpkgs = builtins.fetchGit {
    # Descriptive name to make the store path easier to identify
    name = "nixos-unstable-2024-03-25";
    url = "https://github.com/nixos/nixpkgs/";
    # Commit hash for nixos-unstable as of 2018-09-12
    # `git ls-remote https://github.com/nixos/nixpkgs nixos-unstable`
    ref = "refs/heads/nixos-unstable";
    rev = "44d0940ea560dee511026a53f0e2e2cde489b4d4";
  };
  pkgs = import nixpkgs { config = {}; overlays = []; };
in pkgs.mkShell {
  packages = [ pkgs.ansible pkgs.sshpass ];
}
