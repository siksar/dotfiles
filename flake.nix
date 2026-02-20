{
	description = "NixOS Configuration for Gigabyte Aero X16 (Ryzen AI 7 350 + RTX 5060)";

	inputs = {
		# NixOS Unstable
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

		# Home Manager
		home-manager.url = "github:nix-community/home-manager";
		home-manager.inputs.nixpkgs.follows = "nixpkgs";

		# Stylix - System-wide Theming
		stylix.url = "github:danth/stylix";

		# Noctalia Shell - Latest
		noctalia-shell.url = "github:noctalia-dev/noctalia-shell";
		noctalia-shell.inputs.nixpkgs.follows = "nixpkgs";

		# Zen Browser
		zen-browser.url = "github:0xc000022070/zen-browser-flake";
		zen-browser.inputs.nixpkgs.follows = "nixpkgs";

		# Hyprland
		hyprland.url = "github:hyprwm/Hyprland";
		hyprland.inputs.nixpkgs.follows = "nixpkgs";

		# NixOS Hardware
		nixos-hardware.url = "github:NixOS/nixos-hardware";
	};

	outputs = { self, nixpkgs, home-manager, nixos-hardware, ... }@inputs: {
		nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
			system = "x86_64-linux";
			specialArgs = { inherit inputs; };
			modules = [
				# Hardware Optimizations
				nixos-hardware.nixosModules.common-cpu-amd
				nixos-hardware.nixosModules.common-gpu-amd
				nixos-hardware.nixosModules.common-pc-laptop-ssd

				# System Configuration
				./base/configuration.nix

				# Home Manager Module (Unified System)
				home-manager.nixosModules.home-manager
				{
					home-manager.useGlobalPkgs = true;
					home-manager.useUserPackages = true;
					home-manager.extraSpecialArgs = { inherit inputs; };
					
					# Home User Configuration
					home-manager.users.zixar = import ./home/home.nix;
          
					# Backup existing files just in case
					home-manager.backupFileExtension = "backup";
				}
        
				# System-wide Stylix
				inputs.stylix.nixosModules.stylix
			];
		};
	};
}
