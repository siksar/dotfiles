{ config, pkgs, ... }:
{
	# ========================================================================
	# SYSTEM PACKAGES
	# ========================================================================

	nixpkgs.config.allowUnfree = true;
	environment.systemPackages = with pkgs; [
		# ====================================================================
		# CORE UTILITIES - RUST BASED
		# ====================================================================
		helix        # Modern modal editor (Rust)
		bottom       # System monitor (Rust)
		bat          # Cat clone with syntax highlighting (Rust)
		eza          # Ls clone (Rust)
		fd           # Find clone (Rust)
		ripgrep      # Grep clone (Rust)
		zoxide       # Cd clone (Rust)
		starship     # Shell prompt (Rust)
		yazi         # File manager (Rust)
		
		# ====================================================================
		# RUST DEVELOPMENT ENVIRONMENT
		# ====================================================================
		rustc
		cargo
		rust-analyzer
		clippy
		rustfmt
		# Build Dependencies for Rust Crates
		gcc          # Linker
		pkg-config
		openssl
		gnumake
		cmake
		clang

		# ====================================================================
		# SYSTEM & HARDWARE
		# ====================================================================
		wget
		git
		fastfetch
		nvtopPackages.full
		lact
		antigravity-fhs
		nvme-cli
		smartmontools
		appimage-run
		
		# ====================================================================
		# APPLICATIONS & AI
		# ====================================================================
		vscode
		claude-code
		bitwarden-desktop
		home-manager
		bottles
		lmstudio
		localsend
		wine
		winetricks
		dxvk
		vkd3d
		ytmdesktop
		mpv
		yt-dlp
		
		# ====================================================================
		# GAMING TOOLS
		# ====================================================================
		prismlauncher
		heroic
		protonup-qt
		mangohud
		gamescope
		
		# ====================================================================
		# CONTAINERS & THEMES
		# ====================================================================
		docker
		docker-compose
		gruvbox-gtk-theme
		gruvbox-dark-icons-gtk
	];
	# AppImage binfmt registration
	boot.binfmt.registrations.appimage = {
		wrapInterpreterInShell = false;
		interpreter = "${pkgs.appimage-run}/bin/appimage-run";
		recognitionType = "magic";
		offset = 0;
		mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
		magicOrExtension = ''\x7fELF....AI\x02'';
	};

	programs = {
		git = {
			enable = true;
			config = {
				init.defaultBranch = "main";
			};
		};

	};
}
