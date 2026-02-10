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
      # TOKYO NIGHT THEME
      # ====================================================================
      foreground = "#a9b1d6";
      background = "#1a1b26";
      selection_foreground = "#c0caf5";
      selection_background = "#33467c";
      
      # Cursor
      cursor = "#c0caf5";
      cursor_text_color = "#1a1b26";
      
      # URL color
      url_color = "#73daca";
      
      # Tab bar
      active_tab_foreground = "#1a1b26";
      active_tab_background = "#7aa2f7";
      inactive_tab_foreground = "#545c7e";
      inactive_tab_background = "#292e42";
      
      # Normal colors
      color0 = "#15161e";
      color1 = "#f7768e";
      color2 = "#9ece6a";
      color3 = "#e0af68";
      color4 = "#7aa2f7";
      color5 = "#bb9af7";
      color6 = "#7dcfff";
      color7 = "#a9b1d6";
      
      # Bright colors
      color8 = "#414868";
      color9 = "#f7768e";
      color10 = "#9ece6a";
      color11 = "#e0af68";
      color12 = "#7aa2f7";
      color13 = "#bb9af7";
      color14 = "#7dcfff";
      color15 = "#c0caf5";
      
      # Extended colors
      color16 = "#ff9e64";
      color17 = "#db4b4b";
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
