{ config, pkgs, lib, ... }:
let
	# ========================================================================
	# WLR-WHICH-KEY MENU BUILDER (Theme-only fix)
	# ========================================================================
	mkMenu = name: menu: let
		configFile = pkgs.writeText "wlr-which-key-${name}.yaml" (lib.generators.toYAML {} {
			font = "JetBrainsMono Nerd Font 13";
			background = "#222222ee";
			color = "#c2c2b0";
			border = "#bb7744";    # 🟠 Miasma Orange border
			separator = " ➜ ";
			border_width = 2;
			corner_r = 12;
			padding = 16;
			anchor = "center";
			inherit menu;
		});
	in pkgs.writeShellScriptBin "wlr-menu-${name}" ''
		exec ${lib.getExe pkgs.wlr-which-key} ${configFile}
	'';

	# ========================================================================
	# NEW MENU DEFINITIONS (Sıfırdan Tasarım)
	# ========================================================================

	# 📝 Editor/Files Menu (Mod+W)
	editorMenu = mkMenu "editor" [
		{ key = "y"; desc = " Yazi File Manager"; cmd = "kitty -e yazi"; }
		{ key = "n"; desc = " Neovim (Cwd)"; cmd = "kitty -e nvim ."; }
		{ key = "r"; desc = " Neovim (Root)"; cmd = "kitty -e nvim /"; }
		{ key = "c"; desc = " NixOS Config"; cmd = "kitty -e nvim /etc/nixos"; }
	];

	# 💼 Work Menu (Mod+E)
	workMenu = mkMenu "work" [
		{ key = "a"; desc = " Antigravity AI"; cmd = "kitty -e antigravity"; }
		{ key = "l"; desc = " LM Studio"; cmd = "lm-studio"; }
		{ key = "z"; desc = " Zen Browser"; cmd = "zen"; }
	];

	# 🎵 Media Menu (Mod+S)
	mediaMenu = mkMenu "media" [
		{ key = "y"; desc = " ytfzf (YouTube)"; cmd = "kitty -e ytfzf -t"; }
		{ key = "n"; desc = " ncmpcpp (Music)"; cmd = "kitty -e ncmpcpp"; }
		{ key = "c"; desc = " cava (Visualizer)"; cmd = "kitty -e cava"; }
		{ key = "d"; desc = " deemix"; cmd = "deemix-gui"; }
		{ key = "l"; desc = " lrcget (Lyrics)"; cmd = "lrcget"; }
	];

in
{
	wayland.windowManager.hyprland = {
		enable = true;
		xwayland.enable = true;
		systemd.enable = true;

		settings = {
			monitor = [ "eDP-1, preferred, 0x0, 1" ];

			input = {
				kb_layout = "us,tr";
				repeat_delay = 200;
				repeat_rate = 80;
				follow_mouse = 1;
				touchpad.natural_scroll = true;
			};

			general = {
				gaps_in = 6;
				gaps_out = 12;
				border_size = 0;
				"col.active_border" = lib.mkForce "rgb(bb7744) rgb(c9a554) 45deg";
				"col.inactive_border" = lib.mkForce "rgb(222222)";
				layout = "dwindle";
			};

			decoration = {
				rounding = 10;
				active_opacity = 0.88;
				inactive_opacity = 0.88;
				blur = { enabled = true; size = 8; passes = 2; };
				shadow = {
					enabled = true;
					range = 12;
					color = lib.mkForce "rgba(bb774440)";
				};
			};

			animations = {
				enabled = true;
				bezier = [ "overshot, 0.05, 0.9, 0.1, 1.05" ];
				animation = [
					"windows, 1, 4, overshot, slide"
					"workspaces, 1, 4, default, slide"
				];
			};

			misc = {
				disable_hyprland_logo = true;
				vfr = true;
				enable_swallow = true;
				swallow_regex = "^(kitty|Kitty)$";
			};

			exec-once = [
				"hyprpaper"
				"wl-paste --type text --watch cliphist store"
				"wl-paste --type image --watch cliphist store"
				"noctalia-shell"
				"${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
			];

			"$mod" = "SUPER";

			bind = [
				# Apps
				"$mod, Return, exec, kitty"
				"$mod, Q, killactive"
				"$mod, Space, togglefloating"
				"$mod, F, fullscreen, 1"

				# CUSTOM MENUS
				"$mod, W, exec, ${lib.getExe editorMenu}"
				"$mod, E, exec, ${lib.getExe workMenu}"
				"$mod, S, exec, ${lib.getExe mediaMenu}"

				# NOCTALIA IPC TOGGLES
				"$mod, Z, exec, noctalia-shell ipc call network togglePanel"
				"$mod, X, exec, noctalia-shell ipc call bluetooth togglePanel"
				"$mod, C, exec, noctalia-shell ipc call audio togglePanel"

				# OTHER KEYBINDINGS
				"ALT, Shift_L, exec, hyprctl switchxkblayout all next"
				"$mod, Tab, exec, noctalia-shell ipc call controlCenter toggle"
			];

			bindr = [
				"$mod, SUPER_L, exec, noctalia-shell ipc call launcher toggle"
			];

			# Multimedia
			binde = [
				", XF86AudioRaiseVolume, exec, pamixer -i 5"
				", XF86AudioLowerVolume, exec, pamixer -d 5"
				", XF86AudioMute, exec, pamixer -t"
				", XF86MonBrightnessUp, exec, brightnessctl s +5%"
				", XF86MonBrightnessDown, exec, brightnessctl s 5%-"
			];

			# Workspaces
			bind = [
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
			];

			# Mouse
			bindm = [
				"$mod, mouse:272, movewindow"
				"$mod, mouse:273, resizewindow"
			];
		};
	};

	home.packages = with pkgs; [
		hyprpaper pamixer playerctl brightnessctl
		grim slurp swappy hyprpicker wl-clipboard cliphist grimblast
		wlr-which-key
		editorMenu workMenu mediaMenu
	];
}
