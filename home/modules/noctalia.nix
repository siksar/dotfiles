{ config, pkgs, inputs, lib, ... }:
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
							labelMode = "none";
							occupiedColor = "secondary";
							emptyColor = "secondary";
							focusedColor = "secondary";
							showBadge = false;
							showLabelsOnlyWhenOccupied = false;
						}

					];

					# Center Section
					center = [
						{
							id = "NotificationHistory";
							usePrimaryColor = false;
							colorName = "secondary";
						}
						{
							id = "AudioVisualizer";
							colorName = "secondary";
						}
						{
							id = "Battery";
							displayMode = "icon";
							usePrimaryColor = false;
							colorName = "secondary";
						}
					];

					# Bottom Section (South)
					right = [
						{
							id = "Network";
							usePrimaryColor = false;
							colorName = "secondary";
						}
						{
							id = "Volume";
							usePrimaryColor = false;
							colorName = "secondary";
						}
						{
							id = "Bluetooth";
							usePrimaryColor = false;
							colorName = "secondary";
						}
						{
							id = "SystemMonitor";
							compactMode = true;
							showCpuUsage = true;
							showMemoryUsage = true;
							usePrimaryColor = false;
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

			ui = {
				fontDefault = lib.mkForce "JetBrains Mono";
				fontFixed = lib.mkForce "JetBrainsMono Nerd Font";
				
				# Opacity & Frame
				panelBackgroundOpacity = lib.mkForce 0.85; 
				showOutline = false;
				showCapsule = false;
				
				# Frame Settings
				frameThickness = 4;
				frameRadius = 20;
			};
		};
	};
}
