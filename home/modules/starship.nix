{ config, pkgs, ... }:

{
	programs.starship = {
		enable = true;
		enableZshIntegration = false;

		settings = {
			add_newline = false;
			format = "                        $os$directory$git_branch$character";

			# Palette (Miasma)
			# Orange: #bb7744
			# Brown/Copper: #b36d43
			# Foreground: #c2c2b0
			# Background: #222222

			os = {
				disabled = false;
				style = "bold fg:#bb7744"; # Miasma Orange (Bold)
				format = "[$symbol]($style) ";
				symbols = {
					NixOS = " ";
					Windows = " ";
					Linux = " ";
					Macos = " ";
					Unknown = "?";
				};
			};

			directory = {
				style = "fg:#c2c2b0"; # Miasma Foreground
				format = "[$path]($style) ";
				truncation_length = 3;
				truncation_symbol = "…/";
				read_only = " ";
			};

			git_branch = {
				symbol = " ";
				style = "fg:#666666"; # Miasma Comment/Grey
				format = "[$symbol$branch]($style) ";
			};
			
			git_status = {
				style = "fg:#666666";
				format = "([$all_status$ahead_behind]($style) )";
			};

			character = {
				success_symbol = "[>](bold fg:#b36d43)"; # Miasma Brown/Copper
				error_symbol = "[>](bold fg:#8a6f5c)";    # Miasma Red/Brown
				vimcmd_symbol = "[<](bold fg:#b36d43)";
				vimcmd_visual_symbol = "[V](bold fg:#c9a554)";
				vimcmd_replace_symbol = "[R](bold fg:#bb7744)";
				vimcmd_replace_one_symbol = "[r](bold fg:#bb7744)";
			};
			
			cmd_duration = {
				min_time = 2000;
				format = "[$duration](bold fg:yellow) ";
			};
		};
	};
}
