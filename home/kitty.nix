{ config, pkgs, lib, ... }:
{
	# ========================================================================
	# KITTY TERMINAL - GPU Accelerated Terminal
	# ========================================================================
	programs.kitty = {
		enable = true;
    
		# Explicit Miasma Theme (Adapted) implementation
		# We disable stylix generation below or handle it externally
		# to guarantee the specific orange-focused colors are applied properly.
    
		shellIntegration = {
			enableZshIntegration = false;
			# enableNushellIntegration is not supported yet in Home Manager
		};
    
		settings = {
			# Shell
			shell = "${pkgs.nushell}/bin/nu";
      
			# Window
			window_padding_width = 12;
			confirm_os_window_close = 0;
      
			# Cursor
			cursor_shape = "beam";
			cursor_blink_interval = "0.5";
      
			# Scrollback
			scrollback_lines = 10000;
      
			# URL
			url_style = "curly";
			open_url_with = "default";
      
			# Bell
			enable_audio_bell = false;
			visual_bell_duration = "0.0";

			# --- Miasma Theme (Adapted) Colors ---
			background = "#222222";
			foreground = "#c2c2b0";
			selection_background = "#4a4a4a";
			selection_foreground = "#eeeeee";
			cursor = "#c9a554";
			cursor_text_color = "#222222";
			url_color = "#cc966c";
			active_border_color = "#cc966c";
			inactive_border_color = "#4a4a4a";
			bell_border_color = "#8a6f5c";

			# Normal colors
			color0 = "#222222"; # black
			color1 = "#8a6f5c"; # red
			color2 = "#b36d43"; # green
			color3 = "#c9a554"; # yellow
			color4 = "#c9a554"; # blue
			color5 = "#b36d43"; # magenta
			color6 = "#bb7744"; # cyan
			color7 = "#c2c2b0"; # white

			# Bright colors
			color8  = "#666666";
			color9  = "#cc966c";
			color10 = "#bb7744";
			color11 = "#c9a554";
			color12 = "#c9a554";
			color13 = "#b36d43";
			color14 = "#bb7744";
			color15 = "#eeeeee";
		};
    
		keybindings = {
			"ctrl+shift+c" = "copy_to_clipboard";
			"ctrl+shift+v" = "paste_from_clipboard";
			"ctrl+shift+t" = "new_tab";
			"ctrl+shift+q" = "close_tab";
			"ctrl+shift+right" = "next_tab";
			"ctrl+shift+left" = "previous_tab";
			"ctrl+shift+enter" = "new_window";
			"ctrl+shift+w" = "close_window";
			"ctrl+shift+]" = "next_window";
			"ctrl+shift+[" = "previous_window";
			"ctrl+shift+f" = "show_scrollback";
			"ctrl+shift+equal" = "change_font_size all +2.0";
			"ctrl+shift+minus" = "change_font_size all -2.0";
			"ctrl+shift+backspace" = "change_font_size all 0";
		};
	};
}
