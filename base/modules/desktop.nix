{ config, pkgs, lib, ... }:
{
	# ========================================================================
	# DESKTOP ENVIRONMENT (Hyprland System-Level)
	# ========================================================================

	# Enable Hyprland
	programs.hyprland = {
		enable = true;
		xwayland.enable = true;
	};

	# XServer (X11) - Compatibility & Input
	services.xserver = {
		enable = true;
		videoDrivers = [ "nvidia" "amdgpu" ];
		xkb = {
			layout = "us";
			variant = "";
		};
    
		# Keyboard Repeat Rate (Fix for slow typing)
		autoRepeatDelay = 200;
		autoRepeatInterval = 25;
	};

	# Display Manager (GreetD + ReGreet)
	services.greetd = {
		enable = true;
		settings = {
			default_session = {
				command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
				user = "greeter";
			};
		};
	};
  
	# Environment Session Variables
	environment.sessionVariables = {
		NIXOS_OZONE_WL = "1";
		WLR_NO_HARDWARE_CURSORS = "1";
	};

	# Desktop Portals
	xdg.portal = {
		enable = true;
		extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
	};
  
	# Basic Desktop Packages
	environment.systemPackages = with pkgs; [
		kitty
		wofi
		waybar
		swaynotificationcenter
		libnotify

		hyprpaper
		wl-clipboard
	];
}
