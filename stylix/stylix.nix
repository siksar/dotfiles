# Stylix theme: tek merkez — dotfiles/stylix/stylix.nix
# Tüm tema yapılandırması bu dosyada; hedefler Stylix üzerinden yönetilir.
{ config, pkgs, ... }:
{
	stylix = {
		enable = true;
		polarity = "dark";

		base16Scheme = {
			base00 = "222222";
			base01 = "1c1c1c";
			base02 = "3c3c3c";
			base03 = "5c5c5c";
			base04 = "b4b4b4";
			base05 = "c2c2b0";
			base06 = "d9d9d9";
			base07 = "e8e8e8";
			base08 = "685742";
			base09 = "FF8C00";
			base0A = "c9a554";
			base0B = "5f875f";
			base0C = "c9a554";
			base0D = "FF6600";
			base0E = "b36d43";
			base0F = "c9a554";
		};

		cursor = {
			package = pkgs.adwaita-icon-theme;
			name = "Adwaita";
			size = 24;
		};

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

		targets = {
			grub.enable = false;
			plymouth.enable = true;
			gtk.enable = true;
		};
	};
}
