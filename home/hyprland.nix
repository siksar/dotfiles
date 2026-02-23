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

	# ✍️ Writer / Editor Menu (Mod+W)
	writerMenu = mkMenu "writer" [
		{ key = "q"; desc = " NixOS Config"; cmd = "kitty -e nvim ~/dotfiles/flake"; }
		{ key = "w"; desc = " Obsidian"; cmd = "obsidian"; }
		{ key = "e"; desc = " Neovim (Cwd)"; cmd = "kitty -e nvim ."; }
		{ key = "r"; desc = " Yazi File Manager"; cmd = "kitty -e yazi"; }
		{ key = "t"; desc = " Zed Editor"; cmd = "zeditor"; }
		{ key = "y"; desc = " Neovim (Root)"; cmd = "kitty -e nvim /"; }
	];

	# ⚡ Quick Menu (Mod+E)
	quickMenu = mkMenu "quick" [
		{ key = "q"; desc = " WiFi Settings"; cmd = "noctalia-shell ipc call network togglePanel"; }
		{ key = "w"; desc = " Bluetooth Settings"; cmd = "noctalia-shell ipc call bluetooth togglePanel"; }
		{ key = "e"; desc = " Volume Settings"; cmd = "noctalia-shell ipc call audio togglePanel"; }
	];

	# 🎵 Media Menu (Mod+A)
	mediaMenu = mkMenu "media" [
		{ key = "q"; desc = " YouTube (ytfzf)"; cmd = "kitty -e ytfzf -t"; }
		{ key = "w"; desc = " Music Player (ncmpcpp)"; cmd = "kitty -e ncmpcpp"; }
		{ key = "e"; desc = " Deezer Downloader (deemix)"; cmd = "kitty -e deemix"; }
		{ key = "r"; desc = " Synced Lyrics (lrcsnc)"; cmd = "kitty -e lrcsnc"; }
		{ key = "t"; desc = " Audio Visualizer (cava)"; cmd = "kitty -e cava"; }
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
				touchpad = {
					natural_scroll = true;
				};
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

				# CUSTOM MENUS (Redesigned)
				"$mod, W, exec, ${lib.getExe writerMenu}"
				"$mod, E, exec, ${lib.getExe quickMenu}"
				"$mod, A, exec, ${lib.getExe mediaMenu}"

				# OTHER KEYBINDINGS
				"ALT, Shift_L, exec, hyprctl switchxkblayout all next"
				"$mod, Tab, exec, noctalia-shell ipc call controlCenter toggle"

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

			# Media keys
			bindl = [
				", XF86AudioPlay, exec, playerctl play-pause"
				", XF86AudioNext, exec, playerctl next"
				", XF86AudioPrev, exec, playerctl previous"
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
		writerMenu quickMenu mediaMenu
	];
}
