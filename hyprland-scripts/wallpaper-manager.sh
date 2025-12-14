#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER="$HOME/wallpaper.jpg"

# Create wallpaper directory if it doesn't exist
mkdir -p "$WALLPAPER_DIR"

# Function to set wallpaper
set_wallpaper() {
    local wallpaper="$1"
    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: Wallpaper not found: $wallpaper"
        return 1
    fi
    
    # Copy to default location
    cp "$wallpaper" "$DEFAULT_WALLPAPER"
    
    # Set with swww
    if command -v swww &> /dev/null; then
        swww img "$DEFAULT_WALLPAPER" --transition-fps 75 --transition-type wipe
    fi
    
    echo "Wallpaper set: $wallpaper"
}

# Function to list wallpapers
list_wallpapers() {
    echo "Available wallpapers:"
    if [[ -d "$WALLPAPER_DIR" ]]; then
        find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | nl
    else
        echo "No wallpaper directory found at $WALLPAPER_DIR"
    fi
}

# Function to download wallpapers
download_wallpaper() {
    local url="$1"
    local filename=$(basename "$url")
    local filepath="$WALLPAPER_DIR/$filename"
    
    if [[ -z "$url" ]]; then
        echo "Usage: $0 download <url>"
        return 1
    fi
    
    echo "Downloading wallpaper from $url..."
    if wget -O "$filepath" "$url"; then
        echo "Downloaded: $filepath"
        set_wallpaper "$filepath"
    else
        echo "Error: Failed to download wallpaper"
        return 1
    fi
}

# Main logic
case "$1" in
    "set")
        if [[ $# -ne 2 ]]; then
            echo "Usage: $0 set <wallpaper_path>"
            exit 1
        fi
        set_wallpaper "$2"
        ;;
    "list")
        list_wallpapers
        ;;
    "download")
        if [[ $# -ne 2 ]]; then
            echo "Usage: $0 download <url>"
            exit 1
        fi
        download_wallpaper "$2"
        ;;
    "random")
        local random_wallpaper
        random_wallpaper=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | shuf -n 1)
        if [[ -n "$random_wallpaper" ]]; then
            set_wallpaper "$random_wallpaper"
        else
            echo "No wallpapers found in $WALLPAPER_DIR"
        fi
        ;;
    *)
        echo "Usage: $0 {set|list|download|random}"
        echo "  set <path> - Set wallpaper from file"
        echo "  list - List available wallpapers"
        echo "  download <url> - Download and set wallpaper"
        echo "  random - Set random wallpaper"
        ;;
esac
