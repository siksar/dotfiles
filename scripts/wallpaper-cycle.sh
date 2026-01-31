#!/usr/bin/env bash

# Directory containing wallpapers
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"

# Create directory if it doesn't exist
mkdir -p "$WALLPAPER_DIR"

# Get list of images (sorted)
mapfile -t IMAGES < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | sort)

# Check if we have images
NUM_IMAGES=${#IMAGES[@]}
if [ "$NUM_IMAGES" -eq 0 ]; then
    notify-send "Wallpaper Cycle" "No images found in $WALLPAPER_DIR"
    exit 1
fi

# Get current index
if [ -f "$CACHE_FILE" ]; then
    CURRENT_INDEX=$(cat "$CACHE_FILE")
else
    CURRENT_INDEX=-1
fi

# Calculate next index
NEXT_INDEX=$(( (CURRENT_INDEX + 1) % NUM_IMAGES ))

# Get next image
NEXT_IMAGE="${IMAGES[$NEXT_INDEX]}"

# Apply wallpaper using swww
swww img "$NEXT_IMAGE" --transition-type grow --transition-pos 0.5,0.5 --transition-fps 60 --transition-duration 2

# Save index
echo "$NEXT_INDEX" > "$CACHE_FILE"
