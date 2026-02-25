{ config, pkgs, lib, ... }:
{
	programs.yazi = {
		enable = true;
		enableZshIntegration = false;
		enableNushellIntegration = true;
		shellWrapperName = "y";

		settings = {
			mgr = {
				show_hidden = false;
				sort_by = "alphabetical";
				sort_sensitive = false;
				sort_reverse = false;
				sort_dir_first = true;
				linemode = "none";
				show_symlink = true;
			};

			preview = {
				tab_size = 2;
				max_width = 600;
				max_height = 900;
				cache_dir = "${config.xdg.cacheHome}";
				image_filter = "lanczos3";
				image_quality = 90;
				sixel_fraction = 15;
			};
		};

		# Stylix manages the yazi theme.
		# Removed manual theme block to avoid clashes.
	};
}
