{ config, pkgs, ... }:
{
  # ========================================================================
  # NIRI HOME-MANAGER CONFIGURATION
  # ========================================================================
  wayland.windowManager.niri = {
    settings = {
      # Input configuration
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

      # Output configuration
      outputs = {
        "eDP-1" = {
          scale = 1.0;
          position = {
            x = 0;
            y = 0;
          };
        };
      };

      # Layout configuration
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
          width = 2;
          active-color = "#7aa2f7";
          inactive-color = "#414868";
        };
      };

      # Startup applications
      spawn-at-startup = [
        { command = [ "alacritty" ]; }
        { command = [ "swww-daemon" ]; }
        # Noctalia Shell - will be available via your noctalia module
        { command = [ "noctalia-shell" ]; }
      ];

      # Keybindings
      binds = {
        # Terminal & Apps
        "Mod+Return".action.spawn = [ "alacritty" ];
        "Mod+E".action.spawn = [ "alacritty" "-e" "yazi" ];
        "Mod+R".action.spawn = [ "alacritty" "-e" "hx" "." ];
        "Mod+B".action.spawn = [ "brave" ];
        "Mod+V".action.spawn = [ "zen" ];
        "Mod+D".action.spawn = [ "discord" ];

        # Window management
        "Mod+Q".action.close-window = [];
        "Mod+Left".action.focus-column-left = [];
        "Mod+Right".action.focus-column-right = [];
        "Mod+Up".action.focus-window-up = [];
        "Mod+Down".action.focus-window-down = [];
        "Mod+Shift+Left".action.move-column-left = [];
        "Mod+Shift+Right".action.move-column-right = [];
        "Mod+F".action.maximize-column = [];
        "Mod+Shift+F".action.fullscreen-window = [];
        "Mod+Space".action.center-column = [];
        "Mod+Shift+E".action.quit = [];
        "Mod+Shift+P".action.power-off-monitors = [];

        # Noctalia Integration
        "Mod+Z".action.spawn = [ "noctalia-shell" "ipc" "call" "launcher" "toggle" ];
        "Mod+Tab".action.spawn = [ "noctalia-shell" "ipc" "call" "launcher" "toggle" ];
        "Mod+X".action.spawn = [ "noctalia-shell" "ipc" "call" "controlCenter" "toggle" ];

        # Audio controls
        "XF86AudioRaiseVolume".action.spawn = [ "pamixer" "-i" "5" ];
        "XF86AudioLowerVolume".action.spawn = [ "pamixer" "-d" "5" ];
        "XF86AudioMute".action.spawn = [ "pamixer" "-t" ];
      };
    };
  };

  # ========================================================================
  # NIRI ENVIRONMENT - Ensuring proper Wayland variables
  # ========================================================================
  home.sessionVariables = {
    # These will be set when Niri starts
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # ========================================================================
  # NIRI PACKAGES
  # ========================================================================
  home.packages = with pkgs; [
    # Niri utilities
    swww          # Wallpaper daemon
    pamixer       # Audio control
  ];
}
