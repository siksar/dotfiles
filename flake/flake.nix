{
	description = "Zixar's NixOS Configuration - Gigabyte Aero X16 (Hyprland + Noctalia)";

	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		stylix = {
			url = "github:danth/stylix";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		zen-browser = {
			url = "github:0xc000022070/zen-browser-flake";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		nixos-hardware = {
			url = "github:NixOS/nixos-hardware";
		};
	};

	outputs = {
		self,
		nixpkgs,
		home-manager,
		stylix,
		zen-browser,
		nixos-hardware,
		...
	} @ inputs:
	let
		system = "x86_64-linux";
		pkgs = import nixpkgs {
			inherit system;
			config = {
				allowUnfree = true;
				allowBroken = false;
				permittedInsecurePackages = [ ];
			};
		};

		specialArgs = {
			inherit inputs zen-browser nixos-hardware;
		};
	in {
		nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
			inherit system specialArgs;
			modules = [
				nixos-hardware.nixosModules.common-cpu-amd
				nixos-hardware.nixosModules.common-gpu-amd
				nixos-hardware.nixosModules.common-pc-laptop-ssd

				stylix.nixosModules.stylix

				home-manager.nixosModules.home-manager
				{
					home-manager.useGlobalPkgs = true;
					home-manager.useUserPackages = true;
					home-manager.extraSpecialArgs = specialArgs;
					home-manager.users.zixar = import ../home.nix;
					home-manager.backupFileExtension = "hm-backup";
				}

				../base/configuration.nix
				../stylix/stylix.nix
			];
		};

		devShells.${system}.default = pkgs.mkShell {
			packages = with pkgs; [
				nix-output-monitor
				nix-tree
				nix-diff
				nix-index
				nixpkgs-fmt
				statix
				deadnix
			];
			shellHook = ''
				echo "🔧 NixOS Development Shell"
				echo "Build: nom build .#nixosConfigurations.nixos.config.system.build.toplevel"
			'';
		};
	};
}
