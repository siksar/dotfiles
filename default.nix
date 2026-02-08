# default.nix - Backward compatibility for non-flake commands
# For flake users: Use `nixos-rebuild switch --flake .#nixos`

# This file enables `nix-build`, `nix-env`, and `nix-shell` commands
# to work without explicit flake references.

let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${lock.nodes.nixpkgs.locked.rev}.tar.gz";
    sha256 = lock.nodes.nixpkgs.locked.narHash;
  };
  pkgs = import nixpkgs {
    config.allowUnfree = true;
  };
in
{
  # Re-export pkgs for nix-shell compatibility
  inherit pkgs;
  
  # Import configuration.nix for direct access
  configuration = import ./configuration.nix {
    inherit pkgs;
    config = {};
    lib = pkgs.lib;
    inputs = {};  # Note: inputs won't be available in non-flake mode
  };
}
