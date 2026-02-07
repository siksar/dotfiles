{ config, pkgs, ... }:
{
  # ========================================================================
  # NIRI CONFIGURATION (KDL Format)
  # ========================================================================
  # Note: home-manager doesn't have wayland.windowManager.niri module yet
  # We write the config file directly
  
  xdg.configFile."niri/config.kdl".text = ''
    // Input configuration
    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
            natural-scroll
        }
    }

    // Output configuration
    output "eDP-1" {
        scale 1.0
        position x=0 y=0
    }

    // Layout configuration
    layout {
        gaps 10
        center-focused-column "never"
        
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        
        default-column-width { proportion 0.5; }
        
        focus-ring {
            width 2
            active-color "#7aa2f7"
            inactive-color "#414868"
        }
    }

    // Startup applications
    spawn-at-startup "kitty"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "noctalia-shell"

    // Keybindings
    binds {
        // Terminal & Apps
        Mod+Return { spawn "kitty"; }
        Mod+E { spawn "kitty" "-e" "yazi"; }
        Mod+R { spawn "kitty" "-e" "nvim" "/"; }
        Mod+B { spawn "brave"; }
        Mod+V { spawn "zen"; }
        Mod+D { spawn "discord"; }

        // Window management
        Mod+Q { close-window; }
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up    { focus-window-up; }
        Mod+Down  { focus-window-down; }
        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Space { center-column; }
        Mod+Shift+E { quit; }
        Mod+Shift+P { power-off-monitors; }

        // Noctalia Integration
        Mod+Z { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Mod+Tab { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Mod+X { spawn "noctalia-shell" "ipc" "call" "controlCenter" "toggle"; }

        // Audio controls
        XF86AudioRaiseVolume { spawn "pamixer" "-i" "5"; }
        XF86AudioLowerVolume { spawn "pamixer" "-d" "5"; }
        XF86AudioMute        { spawn "pamixer" "-t"; }
    }
  '';

  # ========================================================================
  # NIRI PACKAGES
  # ========================================================================
  home.packages = with pkgs; [
    swww          # Wallpaper daemon
    pamixer       # Audio control
  ];

  # ========================================================================
  # ENVIRONMENT VARIABLES (for Niri session)
  # ========================================================================
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
