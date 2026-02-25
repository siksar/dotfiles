{ config, pkgs, inputs, noctalia-shell, ... }:
{
	imports = [ ../base/modules/noctalia-home.nix ];

	# ========================================================================
	# NOCTALIA SHELL - Declarative Wayland Desktop Shell
	# ========================================================================
	programs.noctalia-shell = {
		enable = true;
		systemd.enable = true;
		package = inputs.noctalia-shell.packages.${pkgs.system}.default;
		
		settings = {
			appearance = {
				rounding.scale = 1.0;
				padding.scale = 1.0;
				font = {
					family = {
						sans = "Inter";
						mono = "JetBrainsMono Nerd Font";
						clock = "Roboto";
					};
					size.scale = 1.0;
				};
				transparency = {
					enabled = true;
					base = 0.9;
				};
			};

			bar = {
				status = {
					showBattery = true;
					showNetwork = true;
					showBluetooth = true;
					showAudio = true;
					showLockStatus = true;
				};
				sizes = {
					innerWidth = 28;
					windowPreviewSize = 180;
				};
				flat = true;
				padding = 2;
				showOnHover = false;
			};

			general = {
				logo = "nixos";
			};
			
			launcher = {
				actionPrefix = ":";
			};

			paths = {
				wallpaperDir = "~/Pictures/Wallpapers";
			};
		};

		colors = {
			mPrimary = config.lib.stylix.colors.withHashtag.base0D;
			mSecondary = config.lib.stylix.colors.withHashtag.base0E;
			mSurface = config.lib.stylix.colors.withHashtag.base00;
			mOnSurface = config.lib.stylix.colors.withHashtag.base05;
			mOutline = config.lib.stylix.colors.withHashtag.base03;
			mError = config.lib.stylix.colors.withHashtag.base08;
			mSurfaceVariant = config.lib.stylix.colors.withHashtag.base01;
			mOnPrimary = config.lib.stylix.colors.withHashtag.base00;
			mOnSecondary = config.lib.stylix.colors.withHashtag.base00;
			mOnError = config.lib.stylix.colors.withHashtag.base00;
		};
	};
}
