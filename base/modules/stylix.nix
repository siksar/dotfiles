{ config, pkgs, inputs, ... }:
{
	# ========================================================================
	# STYLIX - System-wide Theming (Miasma Orange Edition)
	# ========================================================================

	stylix = {
		enable = true;
		polarity = "dark";

		# Miasma tema + Turuncu override
		# base09/base0D turuncu vurgu, karanlık arka plan ile kontrast
		base16Scheme = {
			base00 = "222222"; # Background
			base01 = "1c1c1c"; # Lighter background
			base02 = "3c3c3c"; # Selection
			base03 = "5c5c5c"; # Comments
			base04 = "b4b4b4"; # Dark foreground
			base05 = "c2c2b0"; # Foreground
			base06 = "d9d9d9"; # Light foreground
			base07 = "e8e8e8"; # Lightest foreground
			base08 = "685742"; # Red (muted brown)
			base09 = "FF8C00"; # 🟠 ORANGE ACCENT (DarkOrange)
			base0A = "c9a554"; # Yellow-gold
			base0B = "5f875f"; # Green (Miasma original)
			base0C = "c9a554"; # Cyan → gold
			base0D = "FF6600"; # 🟠 Blue → Orange (OrangeRed)
			base0E = "b36d43"; # Purple → Orange-brown
			base0F = "c9a554"; # Brown → gold
		};

		# Cursor
		cursor = {
			package = pkgs.adwaita-icon-theme;
			name = "Adwaita";
			size = 24;
		};

		# Fonts
		fonts = {
			monospace = {
				package = pkgs.nerd-fonts.jetbrains-mono;
				name = "JetBrainsMono Nerd Font";
			};
			sansSerif = {
				package = pkgs.noto-fonts;
				name = "Noto Sans";
			};
			serif = {
				package = pkgs.noto-fonts;
				name = "Noto Serif";
			};
			sizes = {
				terminal = 13;
				applications = 11;
				desktop = 11;
			};
		};

		# Targets
		targets = {
			grub.enable = false;
			plymouth.enable = true;
			gtk.enable = true;

			# Apps we configure manually — disable Stylix override
			kitty.enable = false;      # Font/color managed in home/kitty.nix
			hyprland.enable = false;   # Colors managed in home/hyprland.nix
		};
	};
}
