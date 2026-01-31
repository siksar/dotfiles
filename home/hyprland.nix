{ config, pkgs, hyprland, ... }:
{
  # ========================================================================
  # HYPRLAND USER CONFIGURATION - Gruvbox Theme
  # ========================================================================
  
  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
    systemd.enable = true;
    
    settings = {
      # ====================================================================
      # MONITORS
      # ====================================================================
      monitor = ",preferred,auto,1";
      
      # ====================================================================
      # GRUVBOX COLOR VARIABLES
      # ====================================================================
      "$bg" = "rgb(282828)";
      "$bg1" = "rgb(3c3836)";
      "$bg2" = "rgb(504945)";
      "$fg" = "rgb(ebdbb2)";
      "$fg4" = "rgb(a89984)";
      "$red" = "rgb(cc241d)";
      "$green" = "rgb(98971a)";
      "$yellow" = "rgb(d79921)";
      "$blue" = "rgb(458588)";
      "$purple" = "rgb(b16286)";
      "$aqua" = "rgb(689d6a)";
      "$orange" = "rgb(d65d0e)";
      
      # ====================================================================
      # GENERAL
      # ====================================================================
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 0;
        "col.active_border" = "$orange $yellow 45deg";
        "col.inactive_border" = "$bg1";
        layout = "master";
        resize_on_border = true;
      };
      
      # ====================================================================
      # DECORATION
      # ====================================================================
      decoration = {
        rounding = 0;
        
        blur = {
          enabled = true;
          size = 6;
          passes = 3;
          new_optimizations = true;
          xray = true;
        };
        
        shadow = {
          enabled = true;
          range = 12;
          render_power = 3;
          color = "$bg";
        };
        
        active_opacity = 1.0;
        inactive_opacity = 0.95;
      };
      
      # ====================================================================
      # INPUT
      # ====================================================================
      input = {
        kb_layout = "us";
        kb_variant = "";
        follow_mouse = 1;
        sensitivity = 0;
        
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };
      };
      
      
      # ====================================================================
      # ANIMATIONS
      # ====================================================================
      animations = {
        enabled = true;
        
        bezier = [
          "overshot, 0.05, 0.9, 0.1, 1.1"
          "smoothOut, 0.36, 0, 0.66, -0.56"
          "smoothIn, 0.25, 1, 0.5, 1"
          "gruvbox, 0.4, 0, 0.2, 1"
        ];
        
        animation = [
          "windows, 1, 5, overshot, slide"
          "windowsOut, 1, 4, smoothOut, slide"
          "windowsMove, 1, 4, gruvbox"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 5, smoothIn"
          "fadeDim, 1, 5, smoothIn"
          "workspaces, 1, 6, gruvbox, slide"
        ];
      };
      
      # ====================================================================
      # WINDOW RULES - Workstation Profiles (VM Isolation)
      # ====================================================================
      # Window rules moved to extraConfig to avoid syntax issues
      # windowrulev2 = [ ... ];
      
      # ====================================================================
      # LAYOUTS
      # ====================================================================
      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2;
      };
      
      master = {
        new_status = "master";
      };
      
      # ====================================================================
      # MISC
      # ====================================================================
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        animate_manual_resizes = true;
        enable_swallow = true;
        swallow_regex = "^(kitty)$";
      };
      
      # ====================================================================
      # KEY BINDINGS
      # ====================================================================
      "$mod" = "SUPER";
      
      bind = [
        # Applications
        "$mod, Return, exec, kitty"
        "$mod, Q, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, thunar"
        "$mod, B, exec, brave"
        
        # Rofi menus
        "$mod, Z, exec, rofi -show drun -theme ~/.config/rofi/config.rasi"
        "$mod, Tab, exec, rofi -show window -theme ~/.config/rofi/config.rasi"
        "$mod, C, exec, cliphist list | rofi -dmenu -p 'Clipboard' | cliphist decode | wl-copy"
        "$mod, X, exec, rofimoji --action copy"
        "$mod, V, exec, ~/.config/rofi/scripts/powermenu.sh"
        
        # Window management
        "$mod, F, fullscreen, 1"
        "$mod SHIFT, F, fullscreen, 0"
        "$mod, Space, togglefloating,"
        "$mod, P, pseudo,"
        "$mod, J, togglesplit,"
        
        # Focus
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, h, movefocus, l"
        "$mod, l, exec, hyprctl switchxkblayout all next"
        "$mod, k, movefocus, u"
        "$mod, j, movefocus, d"
        
        # Move windows
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, l, exec, hyprlock"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, j, movewindow, d"
        
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
        "$mod, 0, workspace, 10"
        
        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        
        # Scroll through workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
        
        # Screenshot
        ", Print, exec, grimblast copy area"
        "SHIFT, Print, exec, grimblast save area ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
        "CTRL, Print, exec, grimblast copy screen"
        
        # Lock screen
        # "$mod, L, exec, hyprlock" # Rebound to Shift+L above
        
        # Color picker
        "$mod SHIFT, C, exec, hyprpicker -a"
        
        # Notification center
        "$mod, N, exec, dunstctl history-pop"
        "$mod SHIFT, N, exec, dunstctl close-all"
        
        # Wallpaper Cycle
        "$mod, W, exec, ~/.local/bin/wallpaper-cycle"
      ];
      
      # Volume and brightness (hold)
      binde = [
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86AudioMute, exec, pamixer -t"
        ", XF86MonBrightnessUp, exec, brightnessctl s +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl s 5%-"
      ];
      
      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      
      # ====================================================================
      # STARTUP APPLICATIONS
      # ====================================================================
      exec-once = [
        # Core
      
        "dunst"
        
        # Wallpaper
        "swww-daemon"
        "sleep 1 && swww img ~/Pictures/Wallpapers/rice.png --transition-type grow --transition-pos 0.5,0.5"
        
        # Clipboard
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        
        # Polkit
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        
        # Network applet
        "nm-applet --indicator"
      ];
    };
    
    extraConfig = ''
      # ====================================================================
      # WINDOW RULES - Workstation Profiles (VM Isolation)
      # ====================================================================
      # windowrulev2 = workspace 2, title:^(.*Windows.*)$
      # windowrulev2 = workspace 3, class:^(virt-manager)$
    '';
  };
  
  # ========================================================================
  # HYPRPAPER - Wallpaper Configuration
  # ========================================================================
  home.file.".config/hypr/hyprpaper.conf".text = ''
    preload = ~/Pictures/Wallpapers/gruvbox.jpg
    wallpaper = ,~/Pictures/Wallpapers/gruvbox.jpg
    splash = false
  '';
}
