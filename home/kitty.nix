{ config, pkgs, ... }:
{
  # ========================================================================
  # KITTY TERMINAL - GPU Accelerated Terminal
  # ========================================================================
  programs.kitty = {
    enable = true;
    
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    
    shellIntegration = {
      enableZshIntegration = false;
      # enableNushellIntegration is not supported yet in Home Manager
    };
    
    settings = {
      # Shell
      shell = "${pkgs.nushell}/bin/nu";
      
      # Window
      window_padding_width = 12;
      background_opacity = "0.95";
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
      
      # ====================================================================
      # MIASMA THEME (Hardcoded)
      # ====================================================================
      foreground = "#c2c2b0";
      background = "#222222";
      selection_foreground = "#000000";
      selection_background = "#e5c47b";
      
      # Cursor
      cursor = "#c7c7c7";
      cursor_text_color = "#eeeeee";
      
      # URL color
      url_color = "#c9a554";
      
      # Tab bar
      active_tab_foreground = "#222222";
      active_tab_background = "#c9a554";
      inactive_tab_foreground = "#c2c2b0";
      inactive_tab_background = "#2a2a2a";
      
      # Normal colors
      color0 = "#000000";
      color1 = "#685742";
      color2 = "#5f875f";
      color3 = "#b36d43";
      color4 = "#78824b";
      color5 = "#bb7744";
      color6 = "#c9a554";
      color7 = "#d7c483";
      
      # Bright colors
      color8 = "#666666";
      color9 = "#8a6f5c";
      color10 = "#7aa37a";
      color11 = "#d08f5f";
      color12 = "#95a064";
      color13 = "#d89a66";
      color14 = "#e0c080";
      color15 = "#f0e0b0";
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
