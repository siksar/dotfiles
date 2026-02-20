{ config, pkgs, inputs, ... }:
{
	imports = [ inputs.noctalia-shell.homeModules.default ];

	# ========================================================================
	# NOCTALIA SHELL - Hyprland Desktop Shell
	# ========================================================================
	programs.noctalia-shell = {
		enable = true;
		systemd.enable = true;
		package = inputs.noctalia-shell.packages.${pkgs.system}.default;

		settings = {
			# ============================================================
			# BAR CONFIGURATION
			# ============================================================
			bar = {
				position = "left";
				barType = "framed";
				density = "comfortable";
				height = 40;
				transparent = true;

				# Widget Configuration
				widgets = {
					# Top Section (North)
					left = [
						{
							id = "ControlCenter";
							useDistroLogo = true;
							enableColorization = true;
							colorizeSystemIcon = "secondary";
						}
						{
							id = "Workspace";
							labelMode = "none"; # Changed from icon to none
							occupiedColor = "secondary";
							emptyColor = "secondary";
							focusedColor = "secondary";
							showBadge = false;
							showLabelsOnlyWhenOccupied = false; # Ensure labels/icons are managed
						}

					];

					# Center Section
					center = [
						{
							id = "NotificationHistory";
						}
						{
							id = "AudioVisualizer";
							colorName = "secondary";
						}
						{
							id = "Battery";
							displayMode = "icon";
						}
					];

					# Bottom Section (South)
					right = [
						{
							id = "Network";
						}
						{
							id = "Volume";
						}
						{
							id = "Bluetooth";
						}
						{
							id = "SystemMonitor";
							compactMode = true;
							showCpuUsage = true;
							showMemoryUsage = true;
							usePrimaryColor = false; # Secondary implicitly via theme if not primary
							warningColor = "secondary";
							criticalColor = "secondary";
						}
					];
				};
			};

			# ============================================================
			# GLOBAL SETTINGS
			# ============================================================
			theme = {
				mode = "dark";
			};

			location = {
				name = "Erzurum";
				enabled = true;
				weatherEnabled = true;
				useFahrenheit = false;
				use12hourFormat = false;
			};

			calendar = {
				cards = [
					{ id = "calendar-header-card"; enabled = true; }
					{ id = "calendar-month-card"; enabled = true; }
					{ id = "weather-card"; enabled = true; }
				];
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
}
