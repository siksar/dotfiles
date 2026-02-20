{ config, pkgs, inputs, ... }:

{
	imports =
		[
			# Hardware Scan
			./hardware-configuration.nix
      
			# System Modules
			./modules/kernel.nix
			./modules/nvidia.nix
			./modules/networking.nix
			./modules/desktop.nix
			./modules/power-management.nix
			./modules/npu.nix
			./modules/audio.nix
			./modules/cpu-scheduling.nix
			./modules/virtualisation.nix
			./modules/gaming.nix
			./modules/stylix.nix
			./modules/packages.nix
			./modules/nix-optimizations.nix
			./modules/zapret.nix
			./modules/power-efficiency.nix
			./modules/boot.nix
		];

	# ========================================================================
	# SYSTEM SETTINGS
	# ========================================================================

	# Bootloader & Animation (Managed in modules/boot.nix)
	# boot.loader.systemd-boot.enable = true; # Moved
	# boot.loader.efi.canTouchEfiVariables = true; # Moved

	# Networking
	networking.hostName = "aero-x16";
	# networking.networkmanager.enable = true; # Enabled in network.nix

	# Timezone & Locale
	time.timeZone = "Europe/Istanbul";
	i18n.defaultLocale = "en_US.UTF-8";

	i18n.extraLocaleSettings = {
		LC_ADDRESS = "tr_TR.UTF-8";
		LC_IDENTIFICATION = "tr_TR.UTF-8";
		LC_MEASUREMENT = "tr_TR.UTF-8";
		LC_MONETARY = "tr_TR.UTF-8";
		LC_NAME = "tr_TR.UTF-8";
		LC_NUMERIC = "tr_TR.UTF-8";
		LC_PAPER = "tr_TR.UTF-8";
		LC_TELEPHONE = "tr_TR.UTF-8";
		LC_TIME = "tr_TR.UTF-8";
	};

	# User Account
	users.users.zixar = {
		isNormalUser = true;
		description = "Zixar";
		extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" "libvirtd" "kvm" "gamemode" ];
		# shell = pkgs.zsh; # Set in home-manager mostly, but good to have system default
	};
  
	# Allow Unfree Packages
	nixpkgs.config.allowUnfree = true;

	# Flakes
	nix.settings.experimental-features = [ "nix-command" "flakes" ];

	# State Version
	system.stateVersion = "24.05";
}
