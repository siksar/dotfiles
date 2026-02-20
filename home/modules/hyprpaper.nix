{ config, pkgs, lib, ... }:

{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      preload = [
        # Default wallpapers
        "${config.home.homeDirectory}/Pictures/Wallpapers/default.png"
      ];
      wallpaper = [
        ",${config.home.homeDirectory}/Pictures/Wallpapers/default.png"
      ];
    };
  };

  # Script to pick random wallpaper or set specific one and persist it
  home.file.".local/bin/set-wallpaper" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Usage: set-wallpaper [path/to/image]
      
      WP_DIR="$HOME/Pictures/Wallpapers"
      CACHE_FILE="$HOME/.cache/current_wallpaper"
      
      if [ -z "$1" ]; then
        # If no argument, pick random from dir
        WALLPAPER=$(find "$WP_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)
      else
        WALLPAPER="$1"
      fi
      
      if [ -f "$WALLPAPER" ]; then
        echo "Setting wallpaper: $WALLPAPER"
        hyprctl hyprpaper preload "$WALLPAPER"
        hyprctl hyprpaper wallpaper ",$WALLPAPER"
        
        # Determine strict matching for unloading unused is tricky, 
        # but we can try to unload other wallpapers to save RAM if needed.
        # For now just set it.
        
        echo "$WALLPAPER" > "$CACHE_FILE"
        
        # Update Stylix if needed or notify other apps
        # wal -i "$WALLPAPER" # if using pywal
      else
        echo "Error: Wallpaper not found: $WALLPAPER"
        exit 1
      fi
    '';
  };
}
