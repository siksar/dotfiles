{ config, pkgs, lib, ... }:
{
	# ========================================================================
	# HYPRLAND CONFIGURATION - Optimized for Noctalia & Miasma Theme
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
			# GENERAL - Miasma Theme
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
				enable_swallow = true;
				swallow_regex = "^(kitty|Kitty)$";
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
				"hyprpaper"
				"wl-paste --type text --watch cliphist store"
				"wl-paste --type image --watch cliphist store"
				"noctalia-shell"
				# Polkit Agent
				"${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
			];

			# ============================================================
			# KEYBINDINGS
			# ============================================================
			"$mod" = "SUPER";

			bind = [
				# Apps
				"$mod, Return, exec, kitty"
				"$mod, E, exec, kitty -e yazi"
				"$mod, R, exec, kitty -e nvim /"
				"$mod, B, exec, brave"
				"$mod, V, exec, zen"

				# Noctalia Integration (Direct Commands)
				"$mod, Tab, exec, noctalia-shell ipc call controlCenter toggle"
				"$mod, X, exec, noctalia-shell ipc call controlCenter toggle"
				"$mod, W, exec, noctalia-shell ipc call wallpaper random"
				"$mod, S, exec, noctalia-shell ipc call sessionMenu show"
				"$mod, L, exec, noctalia-shell ipc call lockScreen lock"
				"$mod, N, exec, noctalia-shell ipc call notifications showHistory"
				"$mod SHIFT, N, exec, noctalia-shell ipc call notifications closeAll"

				# Window management
				"$mod, Q, killactive"
				"$mod, F, fullscreen, 1"
				"$mod SHIFT, F, fullscreen, 0"
				"$mod, Space, togglefloating"
				"$mod, T, togglesplit"

				# Focus (Arrow keys)
				"$mod, left, movefocus, l"
				"$mod, right, movefocus, r"
				"$mod, up, movefocus, u"
				"$mod, down, movefocus, d"

				# Focus (Vim keys)
				"$mod, H, movefocus, l"
				"$mod, L, movefocus, r"
				"$mod, K, movefocus, u"
				"$mod, J, movefocus, d"

				# Move windows
				"$mod SHIFT, left, movewindow, l"
				"$mod SHIFT, right, movewindow, r"
				"$mod SHIFT, up, movewindow, u"
				"$mod SHIFT, down, movewindow, d"
				"$mod SHIFT, H, movewindow, l"
				"$mod SHIFT, L, movewindow, r"
				"$mod SHIFT, K, movewindow, u"
				"$mod SHIFT, J, movewindow, d"

				# Workspaces
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

				# Screenshot
				", Print, exec, grimblast --notify copy screen"
				"CTRL, Print, exec, grimblast --notify copy area"
				"ALT, Print, exec, grimblast --notify copy active"
				"SHIFT, Print, exec, grimblast save area ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"

				# Color picker
				"$mod SHIFT, C, exec, hyprpicker -a"

				# Session Exit
				"$mod SHIFT, E, exit"
			];

			# Super key alone for App Launcher
			bindr = [
				"$mod, SUPER_L, exec, noctalia-shell ipc call launcher toggle"
			];

			# Volume and brightness (hold)
			binde = [
				", XF86AudioRaiseVolume, exec, pamixer -i 5"
				", XF86AudioLowerVolume, exec, pamixer -d 5"
				", XF86AudioMute, exec, pamixer -t"
				", XF86MonBrightnessUp, exec, brightnessctl s +5%"
				", XF86MonBrightnessDown, exec, brightnessctl s 5%-"
			];

			# Media keys
			bindl = [
				", XF86AudioPlay, exec, playerctl play-pause"
				", XF86AudioNext, exec, playerctl next"
				", XF86AudioPrev, exec, playerctl previous"
			];

			# Mouse bindings
			bindm = [
				"$mod, mouse:272, movewindow"
				"$mod, mouse:273, resizewindow"
			];
		};
	};

	# ========================================================================
	# PACKAGES
	# ========================================================================
	home.packages = with pkgs; [
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
	];
}
