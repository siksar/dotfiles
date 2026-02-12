{ config, pkgs, lib, noctalia, ... }:
{
        # ========================================================================
        # NOCTALIA SHELL - Modern Wayland Desktop Shell
        # ========================================================================

        imports = [ noctalia.homeModules.default ];

	programs.noctalia-shell = {
		enable = true;
		systemd.enable = false;
	};

	# ========================================================================
	# NOCTALIA SETTINGS (Manual JSON Generation)
	# ========================================================================
	# We use xdg.configFile directly to bypass module type checking filtering,
	# ensuring 'colorize' and 'colorKey' properties are preserved in the JSON.
	xdg.configFile."noctalia/settings.json" = {
		force = true;
		text = builtins.toJSON {
			settingsVersion = 53; # Set to latest version to prevent migration

			# ==================================================================
			# BAR CONFIGURATION
			# ==================================================================
			bar = {
				barType = "framed";
				position = "left";
				monitors = [ ];
				density = "comfortable";
				showOutline = false;
				showCapsule = true;
				capsuleOpacity = 0;
				capsuleColorKey = "primary";
				backgroundOpacity = 0.93;
				marginVertical = 4;
				marginHorizontal = 4;
				frameThickness = 10;
				frameRadius = 14;
				outerCorners = true;
				displayMode = "always_visible";
				autoHideDelay = 500;
				autoShowDelay = 150;

				widgets = {
					# TOP
					left = [
						{
							id = "ControlCenter";
							useDistroLogo = true;
							colorize = true;
							colorKey = "tertiary";
						}
						{
							id = "Workspace";
							hideUnoccupied = true;
							labelMode = "none";
							colorKey = "tertiary";
						}
					];

					# MIDDLE
					center = [
						{ id = "AudioVisualizer"; colorKey = "tertiary"; }
					];

					# BOTTOM
					right = [
						{ id = "Network"; colorKey = "tertiary"; }
						{ id = "Bluetooth"; colorKey = "tertiary"; }
						{ id = "Volume"; colorKey = "tertiary"; }
						{
							id = "Clock";
							formatHorizontal = "HH:mm";
							formatVertical = "HH\nmm";
							useMonospacedFont = true;
							colorKey = "tertiary";
						}
					];
				};
				screenOverrides = [ ];
			};

			# ==================================================================
			# GENERAL SETTINGS
			# ==================================================================
			general = {
				avatarImage = "/Pictures/logo.png";
				dimmerOpacity = 0.2;
				showScreenCorners = false;
				scaleRatio = 1;
				radiusRatio = 1;
				animationSpeed = 1;
				compactLockScreen = true;
				lockScreenAnimations = true;
				lockOnSuspend = true;
				enableShadows = true;
				shadowDirection = "bottom_right";
				language = "tr";
				allowPanelsOnScreenWithoutBar = true;
				telemetryEnabled = false;
			};

			# ==================================================================
			# UI & LOCATION
			# ==================================================================
			ui = {
				fontDefault = "JetBrainsMono Nerd Font";
				fontFixed = "JetBrainsMono Nerd Font";
				fontDefaultScale = 1;
				fontFixedScale = 1;
				tooltipsEnabled = true;
				panelBackgroundOpacity = 0.93;
				panelsAttachedToBar = true;
				settingsPanelMode = "attached";
				wifiDetailsViewMode = "grid";
				bluetoothDetailsViewMode = "grid";
				networkPanelView = "wifi";
				boxBorderEnabled = false;
			};

			location = {
				name = "Sivas";
				weatherEnabled = true;
				weatherShowEffects = true;
				useFahrenheit = false;
				use12hourFormat = false;
				firstDayOfWeek = 1;
			};

			# ==================================================================
			# CONTROL CENTER
			# ==================================================================
			controlCenter = {
				position = "close_to_bar_button";
				diskPath = "/";
				shortcuts = {
					left = [
						{ id = "Network"; }
						{ id = "Bluetooth"; }
						{ id = "WallpaperSelector"; }
						{ id = "NoctaliaPerformance"; }
					];
					right = [
						{ id = "Notifications"; }
						{ id = "PowerProfile"; }
						{ id = "KeepAwake"; }
						{ id = "NightLight"; }
					];
				};
				cards = [
					{ enabled = true; id = "profile-card"; }
					{ enabled = true; id = "shortcuts-card"; }
					{ enabled = true; id = "audio-card"; }
					{ enabled = true; id = "brightness-card"; }
					{ enabled = true; id = "weather-card"; }
					{ enabled = true; id = "media-sysmon-card"; }
				];
			};

			# ==================================================================
			# AUDIO & COLORS
			# ==================================================================
			audio = {
				volumeStep = 5;
				cavaFrameRate = 30;
				visualizerType = "linear";
				volumeFeedback = false;
			};

			colorSchemes = {
				useWallpaperColors = false;
				predefinedScheme = "Miasma";
				darkMode = true;
				generationMethod = "tonal-spot";
			};

			# ==================================================================
			# DOCK & WALLPAPER
			# ==================================================================
			dock = {
				enabled = false;
				position = "bottom";
				displayMode = "auto_hide";
				backgroundOpacity = 1;
			};

			wallpaper = {
				enabled = true;
				directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
				setWallpaperOnAllMonitors = true;
				fillMode = "crop";
				wallpaperChangeMode = "random";
				randomIntervalSec = 300;
				transitionDuration = 1500;
				transitionType = "random";
				panelPosition = "follow_bar";
			};

			# ==================================================================
			# APP LAUNCHER
			# ==================================================================
			appLauncher = {
				enableClipboardHistory = true;
				autoPasteClipboard = false;
				enableClipPreview = true;
				clipboardWrapText = true;
				clipboardWatchTextCommand = "wl-paste --type text --watch cliphist store";
				clipboardWatchImageCommand = "wl-paste --type image --watch cliphist store";
				position = "center";
				sortByMostUsed = true;
				terminalCommand = "kitty -e";
				viewMode = "list";
				showCategories = true;
				iconMode = "tabler";
				enableSettingsSearch = true;
				enableWindowsSearch = true;
			};

			# ==================================================================
			# NOTIFICATIONS
			# ==================================================================
			notifications = {
				enabled = true;
				location = "top_right";
				overlayLayer = true;
				backgroundOpacity = 1;
				lowUrgencyDuration = 3;
				normalUrgencyDuration = 8;
				criticalUrgencyDuration = 15;
				enableMediaToast = true;
				enableKeyboardLayoutToast = true;
				enableBatteryToast = true;
			};

			# ==================================================================
			# PLUGINS
			# ==================================================================
			plugins = {
				autoUpdate = false;
				sources = [
					{
						enabled = true;
						name = "Official Noctalia Plugins";
						url = "https://github.com/noctalia-dev/noctalia-plugins";
					}
				];
				states = {
					audiovisualizer = {
						enabled = true;
						sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
					};
				};
				version = 1;
			};

			# ==================================================================
			# DESKTOP WIDGETS
			# ==================================================================
			desktopWidgets = {
				enabled = true;
				gridSnap = false;
				monitorWidgets = [
					{
						id = "Weather";
						position = "top_right";
						usePrimaryColor = true;
						backgroundOpacity = 0.0;
						margin = 20;
					}
					{
						id = "MediaPlayer";
						position = "bottom_center";
						usePrimaryColor = true;
						backgroundOpacity = 0.0;
						margin = 20;
					}
					{
						id = "Clock";
						type = "analog";
						position = "bottom_right";
						usePrimaryColor = true;
						backgroundOpacity = 0.0;
						margin = 20;
					}
				];
			};
		};
	};
}
