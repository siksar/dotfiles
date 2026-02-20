{ config, pkgs, inputs, ... }:
{
	imports = [ inputs.noctalia-shell.homeModules.default ];

	# ========================================================================
	# NOCTALIA SHELL - Hyprland Desktop Shell
	# ========================================================================
	programs.noctalia-shell = {
		enable = true;
    
		settings = {
			# Stylix integration should be handled automatically by the module
			# if Stylix is enabled, but we can enforce some settings here.
      
			layout = {
				bar = {
					position = "left";
					style = "framed";
					spacing = "comfort";
					height = 40;
					transparent = true;
				};
			};

			theme = {
				mode = "dark";
			};

			modules = {
				# Section: Top (North)
				north = [
					"control-center"
					"distro"
					"workspaces"
				];

				# Section: Middle (Center)
				center = [
					"notification-button"
					"audio-visualizer"
					"battery"
				];

				# Section: Bottom (South)
				south = [
					"network"
					"audio"
					"bluetooth"
					"system-stats"
				];

				distro = {
					color = "secondary";
					icon = "nixos";
				};

				workspaces = {
					style = "none";
					color = "secondary";
					show_empty = true;
				};

				clock = {
					format = "%H:%M";
					date_format = "%Y-%m-%d";
				};
			};

			features = {
				wallpaper = {
					enabled = true;
					provider = "noctalia";
				};
				lockscreen = {
					enabled = true;
					provider = "noctalia";
				};
			};
		};
	};
  
	# Ensure Ironbar is configured via Noctalia
	# Note: Noctalia typically wraps Ironbar. 
	# If we need specific Ironbar settings, they might go into programs.ironbar 
	# if Noctalia exposes it or we configure it alongside.
	# For now, we trust Noctalia's module.
}
