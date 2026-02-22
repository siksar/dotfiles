{ config, pkgs, lib, ... }:
let
	# ========================================================================
	# WLR-WHICH-KEY MENU BUILDER (VimJoyer vid74 pattern)
	# ========================================================================
	mkMenu = name: menu: let
		configFile = pkgs.writeText "wlr-which-key-${name}.yaml" (lib.generators.toYAML {} {
			font = "JetBrainsMono Nerd Font 13";
			background = "#222222ee";
			color = "#c2c2b0";
			border = "#FF8C00";    # 🟠 Orange border
			separator = " → ";
			border_width = 2;
			corner_r = 12;
			padding = 16;
			anchor = "center";
			margin_bottom = 0;
			margin_top = 0;
			margin_left = 0;
			margin_right = 0;
			inherit menu;
		});
	in pkgs.writeShellScriptBin "wlr-menu-${name}" ''
		exec ${lib.getExe pkgs.wlr-which-key} ${configFile}
	'';

	# ========================================================================
	# MENU DEFINITIONS
	# ========================================================================

	# 🚀 App Launcher Menu (Mod+D)
	appMenu = mkMenu "apps" [
		{ key = "b"; desc = "Brave Browser"; cmd = "brave"; }
		{ key = "z"; desc = "Zen Browser"; cmd = "zen"; }
		{ key = "d"; desc = "Discord"; cmd = "discord"; }
		{ key = "t"; desc = "Telegram"; cmd = "telegram-desktop"; }
		{ key = "s"; desc = "Spotify (Web)"; cmd = "zen https://open.spotify.com"; }
		{ key = "o"; desc = "OBS Studio"; cmd = "obs"; }
		{ key = "p"; desc = "Pavucontrol"; cmd = "pavucontrol"; }
		{ key = "g"; desc = "GIMP"; cmd = "gimp"; }
		{ key = "m"; desc = "mpv (Last Video)"; cmd = "mpv --player-operation-mode=pseudo-gui"; }
	];

	# 📁 File/Editor Menu (Mod+O)
	fileMenu = mkMenu "files" [
		{ key = "f"; desc = "Yazi File Manager"; cmd = "kitty -e yazi"; }
		{ key = "n"; desc = "Neovim"; cmd = "kitty -e nvim"; }
		{ key = "r"; desc = "Neovim /"; cmd = "kitty -e nvim /"; }
		{ key = "c"; desc = "NixOS Config"; cmd = "kitty -e nvim /etc/nixos"; }
		{ key = "h"; desc = "Home Dir"; cmd = "kitty -e yazi /home/zixar"; }
		{ key = "d"; desc = "Downloads"; cmd = "kitty -e yazi /home/zixar/Downloads"; }
	];

	# 🖥️ System Menu (Mod+S)
	systemMenu = mkMenu "system" [
		{ key = "m"; desc = " System Monitor"; cmd = "kitty -e btop"; }
		{ key = "n"; desc = " Network Manager"; cmd = "kitty -e nmtui"; }
		{ key = "b"; desc = " Bluetooth"; cmd = "blueman-manager"; }
		{ key = "v"; desc = " Volume Control"; cmd = "pavucontrol"; }
		{ key = "w"; desc = " WiFi Settings"; cmd = "ironbar drawers toggle wifi"; }
		{ key = "p"; desc = " Power Profile"; cmd = "ironbar drawers toggle power"; }
	];

	# 🎮 Gaming Menu (Mod+G)
	gamingMenu = mkMenu "gaming" [
		{ key = "s"; desc = " Steam"; cmd = "gamemoderun steam"; }
		{ key = "l"; desc = " Lutris"; cmd = "gamemoderun lutris"; }
		{ key = "h"; desc = " Heroic"; cmd = "gamemoderun heroic"; }
		{ key = "p"; desc = " Prism Launcher"; cmd = "prismlauncher"; }
		{ key = "m"; desc = " MangoHud Config"; cmd = "goverlay"; }
		{ key = "g"; desc = " GPU Monitor"; cmd = "kitty -e nvtop"; }
	];

	# ⚡ Power Menu (Mod+Escape)
	powerMenu = mkMenu "power" [
		{ key = "l"; desc = " Lock Screen"; cmd = "hyprlock"; }
		{ key = "s"; desc = " Suspend"; cmd = "systemctl suspend"; }
		{ key = "h"; desc = " Hibernate"; cmd = "systemctl hibernate"; }
		{ key = "r"; desc = " Reboot"; cmd = "systemctl reboot"; }
		{ key = "p"; desc = " Power Off"; cmd = "systemctl poweroff"; }
		{ key = "e"; desc = " Exit Hyprland"; cmd = "hyprctl dispatch exit"; }
	];

	# 📸 Screenshot Menu (Mod+P)
	screenshotMenu = mkMenu "screenshot" [
		{ key = "s"; desc = " Select Area → Clipboard"; cmd = "grim -g \"$(slurp)\" - | wl-copy"; }
		{ key = "f"; desc = " Full Screen → Clipboard"; cmd = "grim - | wl-copy"; }
		{ key = "a"; desc = " Area → Save File"; cmd = "grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"; }
		{ key = "w"; desc = " Active Window"; cmd = "grimblast --notify copy active"; }
		{ key = "e"; desc = " Edit (Swappy)"; cmd = "grim -g \"$(slurp)\" - | swappy -f -"; }
		{ key = "c"; desc = " Color Picker"; cmd = "hyprpicker -a"; }
	];

	# 🎨 Noctalia Menu (Mod+N)
	noctaliaMenu = mkMenu "noctalia" [
		{ key = "l"; desc = " Launcher"; cmd = "tofi-drun | xargs hyprctl dispatch exec"; }
		{ key = "c"; desc = " Control Center"; cmd = "swaync-client -t -sw"; }
		{ key = "w"; desc = " Wallpaper Random"; cmd = "set-wallpaper"; }
		{ key = "r"; desc = " Reload Shell"; cmd = "systemctl --user restart noctalia"; }
	];

	# 🌐 Language Menu (Mod+L)
	langMenu = mkMenu "language" [
		{ key = "t"; desc = "Turkish (TR)"; cmd = "hyprctl switchxkblayout all next"; }
		{ key = "e"; desc = "English (US) / Switch"; cmd = "hyprctl switchxkblayout all next"; }
	];

in
{
	# ========================================================================
	# HYPRLAND CONFIGURATION (Declarative via Home Manager)
	# ========================================================================

	wayland.windowManager.hyprland = {
		enable = true;
		xwayland.enable = true;
		systemd.enable = true;

		settings = {
			# ============================================================
			# MONITOR
			# ============================================================
			monitor = [
				"eDP-1, preferred, 0x0, 1"
			];

			# ============================================================
			# INPUT
			# ============================================================
			input = {
				kb_layout = "us,tr";
				repeat_delay = 200;
				repeat_rate = 80;
				follow_mouse = 1;
				sensitivity = 0;
				touchpad = {
					natural_scroll = true;
					tap-to-click = true;
					disable_while_typing = true;
					scroll_factor = 0.3;
				};
			};

			# ============================================================
			# GENERAL - Orange Theme
			# ============================================================
			general = {
				gaps_in = 6;
				gaps_out = 12;
				border_size = 0;
				"col.active_border" = lib.mkForce "rgb(bb7744) rgb(c9a554) 45deg";   # 🟠 Miasma Orange/Gold
				"col.inactive_border" = lib.mkForce "rgb(222222)";
				layout = "dwindle";
				allow_tearing = false;
			};

			# ============================================================
			# DECORATION
			# ============================================================
			decoration = {
				rounding = 10;
				active_opacity = 0.88;
				inactive_opacity = 0.88;
				blur = {
					enabled = true;
					size = 8;
					passes = 2;
					new_optimizations = true;
					xray = false;
				};
				shadow = {
					enabled = true;
					range = 12;
					render_power = 3;
					color = lib.mkForce "rgba(bb774440)";   # 🟠 Miasma Orange tinted shadow
				};
			};

			# ============================================================
			# ANIMATIONS
			# ============================================================
			animations = {
				enabled = true;
				bezier = [
					"easeOutExpo, 0.16, 1, 0.3, 1"
					"easeOutQuad, 0.25, 0.46, 0.45, 0.94"
					"overshot, 0.05, 0.9, 0.1, 1.05"
				];
				animation = [
					"windows, 1, 4, overshot, slide"
					"windowsOut, 1, 3, easeOutQuad, popin 80%"
					"border, 1, 5, default"
					"borderangle, 1, 8, default"
					"fade, 1, 3, easeOutQuad"
					"workspaces, 1, 4, easeOutExpo, slide"
				];
			};

			# ============================================================
			# DWINDLE LAYOUT
			# ============================================================
			dwindle = {
				pseudotile = true;
				preserve_split = true;
				force_split = 2;
			};

			# ============================================================
			# MISC
			# ============================================================
			misc = {
				disable_hyprland_logo = true;
				disable_splash_rendering = true;
				vfr = true;
				vrr = 0;
				mouse_move_enables_dpms = true;
				key_press_enables_dpms = true;
			};

			# ============================================================
			# ENVIRONMENT VARIABLES
			# ============================================================
			env = [
				"XCURSOR_SIZE, 24"
				"XCURSOR_THEME, Adwaita"
				"XDG_CURRENT_DESKTOP, Hyprland"
				"XDG_SESSION_TYPE, wayland"
				"XDG_SESSION_DESKTOP, Hyprland"
				"GDK_BACKEND, wayland,x11"
				"QT_QPA_PLATFORM, wayland;xcb"
				"SDL_VIDEODRIVER, wayland"
				"CLUTTER_BACKEND, wayland"
				"MOZ_ENABLE_WAYLAND, 1"
				"NIXOS_OZONE_WL, 1"
			];

			# ============================================================
			# STARTUP
			# ============================================================
			exec-once = [
				# "swww-daemon" # Removed
				"hyprpaper"
				"wl-paste --type text --watch cliphist store"
				"wl-paste --type image --watch cliphist store"
				# "noctalia-shell" # Started by Home Manager systemd service usually, but adding exec-once if needed
				"launch-void-vm"
			];

			# ============================================================
			# WINDOW RULES
			# ============================================================
			windowrulev2 = [];

			# ============================================================
			# KEYBINDINGS
			# ============================================================
			"$mod" = "SUPER";

			bind = [
				# ========================================
				# TERMINAL & DIRECT APPS
				# ========================================
				"$mod, Return, exec, kitty"
				"$mod, E, exec, kitty -e yazi"
				"$mod, R, exec, kitty -e nvim /"
				"$mod, V, exec, zen"

				# ========================================
				# WLR-WHICH-KEY MENUS
				# ========================================
				"$mod, D, exec, ${lib.getExe appMenu}"
				"$mod, O, exec, ${lib.getExe fileMenu}"
				"$mod, S, exec, ${lib.getExe systemMenu}"
				"$mod, G, exec, ${lib.getExe gamingMenu}"
				"$mod, P, exec, ${lib.getExe screenshotMenu}"
				"$mod, N, exec, ${lib.getExe noctaliaMenu}"
				"$mod, L, exec, ${lib.getExe langMenu}"
				"$mod, Escape, exec, ${lib.getExe powerMenu}"

				# ========================================
				# NOCTALIA INTEGRATIONS
				# ========================================
			#	"$mod, Z, exec, tofi-drun"
			#	"$mod, B, exec, swaync-client -t -sw"

				# ========================================
				# WINDOW MANAGEMENT
				# ========================================
				"$mod, Q, killactive"
				"$mod, F, fullscreen, 1"        # Maximize
				"$mod SHIFT, F, fullscreen, 0"  # True fullscreen
				"$mod, Space, togglefloating"
				"$mod, T, togglesplit"

				# Focus (Arrow keys)
				"$mod, left, movefocus, l"
				"$mod, right, movefocus, r"
				"$mod, up, movefocus, u"
				"$mod, down, movefocus, d"

				# Focus (Vim keys)
				"$mod, H, movefocus, l"
				"$mod, J, movefocus, d"
				"$mod, K, movefocus, u"

				# Move windows (Arrow keys)
				"$mod SHIFT, left, movewindow, l"
				"$mod SHIFT, right, movewindow, r"
				"$mod SHIFT, up, movewindow, u"
				"$mod SHIFT, down, movewindow, d"

				# Move windows (Vim keys)
				"$mod SHIFT, H, movewindow, l"
				"$mod SHIFT, L, movewindow, r"
				"$mod SHIFT, K, movewindow, u"
				"$mod SHIFT, J, movewindow, d"

				# ========================================
				# WORKSPACE MANAGEMENT
				# ========================================
				"$mod, 1, workspace, 1"
				"$mod, 2, workspace, 2"
				"$mod, 3, workspace, 3"
				"$mod, 4, workspace, 4"
				"$mod, 5, workspace, 5"
				"$mod, 6, workspace, 6"
				"$mod, 7, workspace, 7"
				"$mod, 8, workspace, 8"
				"$mod, 9, workspace, 9"

				"$mod SHIFT, 1, movetoworkspace, 1"
				"$mod SHIFT, 2, movetoworkspace, 2"
				"$mod SHIFT, 3, movetoworkspace, 3"
				"$mod SHIFT, 4, movetoworkspace, 4"
				"$mod SHIFT, 5, movetoworkspace, 5"
				"$mod SHIFT, 6, movetoworkspace, 6"
				"$mod SHIFT, 7, movetoworkspace, 7"
				"$mod SHIFT, 8, movetoworkspace, 8"
				"$mod SHIFT, 9, movetoworkspace, 9"

				# ========================================
				# MONITOR MANAGEMENT
				# ========================================
				"$mod CTRL, left, focusmonitor, l"
				"$mod CTRL, right, focusmonitor, r"
				"$mod CTRL SHIFT, left, movewindow, mon:l"
				"$mod CTRL SHIFT, right, movewindow, mon:r"
				"$mod SHIFT, P, dpms, off"

				# ========================================
				# SESSION
				# ========================================
				"$mod SHIFT, E, exit"

				# ========================================
				# RESIZE
				# ========================================
				"$mod, minus, splitratio, -0.1"
				"$mod, equal, splitratio, +0.1"

				# ========================================
				# SCREENSHOT (Direct)
				# ========================================
				", Print, exec, grimblast --notify copy screen"
				"CTRL, Print, exec, grimblast --notify copy area"
				"ALT, Print, exec, grimblast --notify copy active"

				# ========================================
				# MEDIA & HARDWARE KEYS
				# ========================================
				", XF86AudioRaiseVolume, exec, pamixer -i 5"
				", XF86AudioLowerVolume, exec, pamixer -d 5"
				", XF86AudioMute, exec, pamixer -t"
				", XF86AudioPlay, exec, playerctl play-pause"
				", XF86AudioNext, exec, playerctl next"
				", XF86AudioPrev, exec, playerctl previous"
				", XF86MonBrightnessUp, exec, brightnessctl s +5%"
				", XF86MonBrightnessDown, exec, brightnessctl s 5%-"

				# ========================================
				# SCROLL WORKSPACES
				# ========================================
				"$mod, mouse_down, workspace, e+1"
				"$mod, mouse_up, workspace, e-1"
			];

			# Mouse binds
			bindm = [
				"$mod, mouse:272, movewindow"
				"$mod, mouse:273, resizewindow"
			];
		};
	};

	# ========================================================================
	# HYPRLAND PACKAGES
	# ========================================================================
	home.packages = with pkgs; [
		wlr-which-key   # Which-key overlay for Wayland
		hyprpaper        # Wallpaper daemon
		pamixer          # Audio control
		playerctl        # Media player control
		brightnessctl    # Brightness control
		grim             # Screenshot
		slurp            # Region selection
		swappy           # Screenshot editor
		hyprpicker       # Color picker
		wl-clipboard     # Clipboard
		cliphist         # Clipboard history
		grimblast        # Hyprland screenshot helper

		# All wlr-which-key menu scripts
		appMenu
		fileMenu
		systemMenu
		gamingMenu
		powerMenu
		screenshotMenu
		noctaliaMenu
		langMenu
	];
}
