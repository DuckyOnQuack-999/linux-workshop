#!/usr/bin/env bash

# Enhanced color scheme generator with error handling
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER="$HOME/wallpaper.jpg"

# Check if pywal is installed
if ! command -v wal &> /dev/null; then
    echo "Error: pywal is not installed. Installing..."
    pip install pywal
fi

# Function to find wallpaper
find_wallpaper() {
    if [[ -f "$DEFAULT_WALLPAPER" ]]; then
        echo "$DEFAULT_WALLPAPER"
    elif [[ -d "$WALLPAPER_DIR" ]] && [[ -n "$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | head -1)" ]]; then
        find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | shuf -n 1
    else
        echo "No wallpaper found. Please place a wallpaper at $DEFAULT_WALLPAPER or in $WALLPAPER_DIR"
        exit 1
    fi
}

# Get wallpaper path
WALLPAPER=$(find_wallpaper)

if [[ ! -f "$WALLPAPER" ]]; then
    echo "Error: Wallpaper not found: $WALLPAPER"
    exit 1
fi

echo "Using wallpaper: $WALLPAPER"

# Generate color scheme
wal -i "$WALLPAPER" -n

# Check if colors were generated
if [[ ! -f "$HOME/.cache/wal/colors.sh" ]]; then
    echo "Error: Failed to generate colors"
    exit 1
fi

# Source the generated colors
source "$HOME/.cache/wal/colors.sh"

# Update Hyprland colors
cat > "$HOME/.config/hypr/colors.conf" << EOF
general {
    col.active_border = rgba(${color2:1}ee) rgba(${color4:1}ee) 45deg
    col.inactive_border = rgba(${color8:1}aa)
}

misc {
    background_color = rgba(${color0:1}FF)
}

plugin {
    hyprbars {
        bar_text_font = Rubik, Geist, AR One Sans, Reddit Sans, Inter, Roboto, Ubuntu, Noto Sans, sans-serif
        bar_height = 30
        bar_padding = 10
        bar_button_padding = 5
        bar_precedence_over_border = true
        bar_part_of_window = true
        bar_color = rgba(${color0:1}FF)
        col.text = rgba(${color7:1}FF)
        
        hyprbars-button = rgb(${color7:1}), 13, 󰖭, hyprctl dispatch killactive
        hyprbars-button = rgb(${color7:1}), 13, 󰖯, hyprctl dispatch fullscreen 1
        hyprbars-button = rgb(${color7:1}), 13, 󰖰, hyprctl dispatch movetoworkspacesilent special
    }
}

decoration {
    col.shadow = rgba(${color0:1}ee)
    col.shadow_inactive = rgba(${color8:1}aa)
}

windowrulev2 = bordercolor rgba(${color2:1}AA) rgba(${color2:1}77),pinned:1
EOF

echo "Color scheme updated successfully!"
echo "Reload Hyprland configuration to apply changes: hyprctl reload"
