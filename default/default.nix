# default.nix - Backward compatibility for non-flake commands
# Flake kullanıcıları: nixos-rebuild switch --flake ../flake#nixos
# Bu dosya: nix-build default, nix-env, nix-shell için (flake referansı olmadan).

let
	lock = builtins.fromJSON (builtins.readFile ../flake/flake.lock);
	nixpkgs = fetchTarball {
		url = "https://github.com/NixOS/nixpkgs/archive/${lock.nodes.nixpkgs.locked.rev}.tar.gz";
		sha256 = lock.nodes.nixpkgs.locked.narHash;
	};
	pkgs = import nixpkgs {
		config.allowUnfree = true;
	};
in
{
	inherit pkgs;

	configuration = import ../base/configuration.nix {
		inherit pkgs;
		config = { };
		lib = pkgs.lib;
		inputs = { };
	};
}
