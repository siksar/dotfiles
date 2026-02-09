{ config, pkgs, ... }:
{
  # ========================================================================
  # HYPRLOCK - Screen Lock with Gruvbox Theme
  # ========================================================================
  
  programs.hyprlock = {
    enable = true;
    
    settings = {
      # Source Noctalia generated theme (if exists)
      # Fallback colors will be used if file doesn't exist
      source = [ "~/.config/hypr/hyprlock-theme.conf" ];
      
      general = {
        disable_loading_bar = false;
        hide_cursor = true;
        grace = 5;
        no_fade_in = false;
        no_fade_out = false;
      };
      
      # Background
      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
          noise = 0.0117;
          contrast = 0.9;
          brightness = 0.7;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
          color = "rgba(40, 40, 40, 1.0)";
        }
      ];
      
      # Password input
      input-field = [
        {
          size = "280, 55";
          outline_thickness = 3;
          dots_size = 0.25;
          dots_spacing = 0.2;
          dots_center = true;
          dots_rounding = -1;
          outer_color = "rgb(214, 93, 14)";       # Gruvbox orange
          inner_color = "rgb(60, 56, 54)";         # Gruvbox bg1
          font_color = "rgb(235, 219, 178)";       # Gruvbox fg
          fade_on_empty = false;
          fade_timeout = 2000;
          placeholder_text = "<i>  Enter Password...</i>";
          hide_input = false;
          rounding = 10;
          check_color = "rgb(152, 151, 26)";       # Gruvbox green
          fail_color = "rgb(204, 36, 29)";         # Gruvbox red
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          fail_transition = 300;
          capslock_color = "rgb(215, 153, 33)";    # Gruvbox yellow
          numlock_color = -1;
          bothlock_color = -1;
          invert_numlock = false;
          position = "0, -100";
          halign = "center";
          valign = "center";
        }
      ];
      
      # Labels
      label = [
        # Time
        {
          text = ''cmd[update:1000] date +"%H:%M"'';
          color = "rgb(235, 219, 178)";
          font_size = 90;
          font_family = "JetBrainsMono Nerd Font Bold";
          position = "0, 200";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(0, 0, 0, 0.5)";
        }
        
        # Date
        {
          text = ''cmd[update:60000] date +"%A, %d %B %Y"'';
          color = "rgb(168, 153, 132)";
          font_size = 22;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
        
        # User greeting
        {
          text = "  Welcome, $USER";
          color = "rgb(214, 93, 14)";
          font_size = 18;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -40";
          halign = "center";
          valign = "center";
        }
        
        # Uptime
        {
          text = ''cmd[update:60000] echo "󰅐 $(uptime -p | sed 's/up //')"'';
          color = "rgb(131, 165, 152)";
          font_size = 14;
          font_family = "JetBrainsMono Nerd Font";
          position = "20, 20";
          halign = "left";
          valign = "bottom";
        }
        
        # Battery (if laptop)
        {
          text = ''cmd[update:5000] cat /sys/class/power_supply/BAT0/capacity 2>/dev/null | xargs -I {} echo "󰁹 {}%" || echo ""'';
          color = "rgb(104, 157, 106)";
          font_size = 14;
          font_family = "JetBrainsMono Nerd Font";
          position = "-20, 20";
          halign = "right";
          valign = "bottom";
        }
      ];
    };
  };
  
  # ========================================================================
  # HYPRIDLE - Idle Management
  # ========================================================================
  
  services.hypridle = {
    enable = true;
    
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      
      listener = [
        # Dim screen after 4 minutes
        {
          timeout = 240;
          on-timeout = "brightnessctl -s set 30%";
          on-resume = "brightnessctl -r";
        }
        
        # Lock after 5 minutes
        {
          timeout = 300;
          on-timeout = "hyprlock";
        }
        
        # Turn off screen after 10 minutes
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        
        # Suspend after 30 minutes
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
