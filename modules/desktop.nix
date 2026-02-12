{ config, pkgs, ... }:
{
	# ========================================================================
	# DESKTOP ENVIRONMENT - Niri
	# ========================================================================
	services = {
		xserver = {
			enable = true;
			xkb.layout = "us";
			autoRepeatDelay = 300;
			autoRepeatInterval = 20;
		};
	};
	# ========================================================================
	# NIRI WINDOW MANAGER (Rust Based)
	# ========================================================================
	programs.niri = {
		enable = true;
		# Niri package from flake input will be used automatically via nixosModules.niri
	};
	# ========================================================================
	# GDM DISPLAY MANAGER (GNOME Based, Wayland Native)
	# ========================================================================
	services.displayManager.gdm = {
		enable = true;
	};
	# ========================================================================
	# ESSENTIAL DESKTOP PACKAGES
	# ========================================================================
	environment.systemPackages = with pkgs; [
		# Archive manager
		file-roller
		# Image viewer
		imv
		# System
		adwaita-icon-theme
		papirus-icon-theme
		pavucontrol
		# SDDM Theme - Tokyo Night (Note: Using GDM now but keeping package just in case)
		(pkgs.where-is-my-sddm-theme.override {
			themeConfig.General = {
				background = "/etc/nixos/logo.jpg";
				backgroundMode = "fill";
				blurRadius = 80;
				passwordCharacter = "●";
				showUsersByDefault = true;
				# Tokyo Night Storm colors
				basicTextColor = "#c0caf5";
				accentColor = "#7aa2f7";
				passwordCursorColor = "#bb9af7";
				passwordInputBackground = "#1a1b26";
				passwordInputWidth = 0.4;
			};
		})
		# Xwayland satellite for Niri X11 compatibility
		xwayland-satellite
	];
	# ========================================================================
	# DCONF & GTK INTEGRATION
	# ========================================================================
	programs.dconf.enable = true;
	# Cursor theme
	environment.variables = {
		XCURSOR_THEME = "Adwaita";
		XCURSOR_SIZE = "24";
	};
	# ========================================================================
	# XDG PORTAL - Niri + GTK
	# ========================================================================
	xdg.portal = {
		enable = true;
		extraPortals = [
			pkgs.xdg-desktop-portal-gtk
			pkgs.xdg-desktop-portal-gnome
		];
		config = {
			niri.default = [ "gnome" "gtk" ];
			common.default = [ "gtk" ];
		};
	};
}
