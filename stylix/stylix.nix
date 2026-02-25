# Stylix theme: tek merkez — dotfiles/stylix/stylix.nix
# Tüm tema yapılandırması bu dosyada; hedefler Stylix üzerinden yönetilir.
{ config, pkgs, ... }:
{
	stylix = {
		enable = true;
		polarity = "dark";

		# Tokyo Night Dark theme
		base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";

		cursor = {
			package = pkgs.adwaita-icon-theme;
			name = "Adwaita";
			size = 24;
		};

		iconTheme = {
			enable = true;
			package = pkgs.papirus-icon-theme;
			dark = "Papirus-Dark";
			light = "Papirus";
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
