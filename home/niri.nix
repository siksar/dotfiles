{ config, pkgs, ... }:
{
  programs.niri = {
    enable = true;
    settings = {
      input = {
        keyboard = {
          xkb = {
            layout = "us";
          };
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
      };
      
      output = {
        "eDP-1" = {
          scale = 1.0;
          position = { x = 0; y = 0; };
        };
      };
      
      layout = {
        gaps = 10;
        center-focused-column = "never";
        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];
        default-column-width = { proportion = 0.5; };
        focus-ring = {
          enable = true;
          width = 2;
          active-color = "#7aa2f7"; # Tokyo Night Blue
          inactive-color = "#414868";
        };
      };
      
      spawn-at-startup = [
        { command = ["noctalia-shell"]; }
        { command = ["swww-daemon"]; }
        { command = ["/usr/libexec/polkit-gnome-authentication-agent-1"]; }
      ];
      
      binds = with config.lib.niri.actions; {
        "Mod+Return".action = spawn "alacritty";
        "Mod+E".action = spawn "alacritty" "-e" "yazi";
        "Mod+R".action = spawn "alacritty" "-e" "hx" ".";
        "Mod+B".action = spawn "brave";
        "Mod+V".action = spawn "zen";
        
        # Noctalia Integration
        "Mod+Z".action = spawn "noctalia-shell" "ipc" "call" "launcher" "toggle";
        "Mod+Tab".action = spawn "noctalia-shell" "ipc" "call" "launcher" "toggle";
        "Mod+X".action = spawn "noctalia-shell" "ipc" "call" "controlCenter" "toggle";
        
        "Mod+Q".action = close-window;
        
        "Mod+Left".action = focus-column-left;
        "Mod+Right".action = focus-column-right;
        "Mod+Up".action = focus-window-up;
        "Mod+Down".action = focus-window-down;
        
        "Mod+Shift+Left".action = move-column-left;
        "Mod+Shift+Right".action = move-column-right;
        
        "Mod+F".action = maximize-column;
        "Mod+Shift+F".action = fullscreen-window;
        "Mod+Space".action = center-column;
        
        "Mod+Shift+E".action = quit;
        "Mod+Shift+P".action = power-off-monitors;
      };
    };
  };
}
