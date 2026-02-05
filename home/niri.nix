{ config, pkgs, ... }:
{
  # ========================================================================
  # NIRI CONFIGURATION (Manual KDL Generation)
  # ========================================================================
  # We use manual file generation to avoid dependency on Home Manager modules
  # which might differ between versions/flakes.
  
  home.packages = [ pkgs.niri ];

  xdg.configFile."niri/config.kdl".text = ''
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

    output "eDP-1" {
        scale 1.0
        position x=0 y=0
    }

    prefer-no-csd

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
    
    window-rule {
        geometry-corner-radius 12
        clip-to-geometry true
    }

    spawn-at-startup "zixar-niri-session"

    binds {
        Mod+Return { spawn "alacritty"; }
        Mod+E { spawn "alacritty" "-e" "yazi"; }
        Mod+R { spawn "alacritty" "-e" "hx" "."; }
        Mod+B { spawn "brave"; }
        Mod+V { spawn "zen"; }

        // Noctalia Integration
        Mod+Z { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Mod+Tab { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Mod+X { spawn "noctalia-shell" "ipc" "call" "controlCenter" "toggle"; }

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
        
        // Volume
        XF86AudioRaiseVolume { spawn "pamixer" "-i" "5"; }
        XF86AudioLowerVolume { spawn "pamixer" "-d" "5"; }
        XF86AudioMute        { spawn "pamixer" "-t"; }
    }
  '';
}
