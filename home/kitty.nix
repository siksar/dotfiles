{ config, pkgs, lib, ... }:
{
	# ========================================================================
	# KITTY TERMINAL - GPU Accelerated Terminal
	# ========================================================================
	programs.kitty = {
		enable = true;
    
		# Stylix overrides kitty terminal settings natively.
		# Removed manual font and background_opacity to avoid mkForce clashes.
    
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
