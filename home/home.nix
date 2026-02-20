{ config, pkgs, inputs, ... }:

{
	# ========================================================================
	# HOME MANAGER CONFIGURATION
	# ========================================================================
	home.username = "zixar";
	home.homeDirectory = "/home/zixar";
	home.stateVersion = "24.05";

	# ========================================================================
	# IMPORTS
	# ========================================================================
	imports = [
		./modules/hyprland.nix
		./modules/noctalia.nix
		./modules/hyprpaper.nix
		./modules/kitty.nix
		./modules/starship.nix
		./modules/fastfetch.nix
		./modules/yazi.nix
		./modules/browsers.nix
		./modules/editors.nix
		./modules/gaming.nix
		./modules/tui-media.nix
		./modules/nushell.nix
		./modules/wrappers.nix
		inputs.hyprland.homeManagerModules.default
	];

	# ========================================================================
	# HOME MANAGER
	# ========================================================================
	programs.home-manager.enable = true;

	# ========================================================================
	# GIT CONFIGURATION
	# ========================================================================
	programs.git = {
		enable = true;
		userName = "zixar";
		userEmail = "zixar@example.com"; # Update this if known
		extraConfig = {
			init.defaultBranch = "main";
			pull.rebase = false;
		};
	};

	# ========================================================================
	# ZSH CONFIGURATION (Fallback/Alternative Shell)
	# ========================================================================
	programs.zsh = {
		enable = true;
		enableCompletion = true;
		autosuggestion.enable = true;
		syntaxHighlighting.enable = true;
    
		shellAliases = {
			ll = "ls -l";
			update = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
		};

		history = {
			size = 10000;
			path = "${config.xdg.dataHome}/zsh/history";
		};
	};

	# ========================================================================
	# PACKAGES
	# ========================================================================
	home.packages = with pkgs; [
		# Archives
		zip
		unzip
		xz
		p7zip
		ripgrep
		jq
		eza
		fzf
		file
		which
		tree
		gnused
		gnutar
		gawk
		zstd
		gnupg
    
		# Networking
		mtr
		iperf3
		dnsutils
		ldns
		aria2
		socat
		nmap
		ipcalc
    
		# SysAdmin
		btop
		iotop
		iftop
		strace
		ltrace
		lsof
		sysstat
		lm_sensors
		ethtool
		pciutils
		usbutils
	];

	# ========================================================================
	# SESSION VARIABLES
	# ========================================================================
	home.sessionVariables = {
		EDITOR = "nvim";
		VISUAL = "nvim";
		NIXOS_OZONE_WL = "1"; # Force Wayland for Electron apps
	};
}
