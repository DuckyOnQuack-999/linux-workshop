#!/usr/bin/env bash

# Configuration validation script
echo "=== Hyprland Configuration Validation ==="
echo

# Check if Hyprland is running
if ! pgrep -x "Hyprland" > /dev/null; then
    echo "❌ Hyprland is not running"
    echo "   Please start Hyprland first"
    exit 1
else
    echo "✅ Hyprland is running"
fi

# Check configuration files
config_files=(
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.config/hypr/colors.conf"
    "$HOME/.config/hypr/rules.conf"
    "$HOME/.config/hypr/keybinds.conf"
    "$HOME/.config/hypr/hypridle.conf"
    "$HOME/.config/hypr/hyprlock.conf"
)

for config in "${config_files[@]}"; do
    if [[ -f "$config" ]]; then
        echo "✅ $config exists"
    else
        echo "❌ $config missing"
    fi
done

# Check if hyprctl can parse the config
echo
echo "Validating configuration syntax..."
if hyprctl reload 2>&1 | grep -q "error"; then
    echo "❌ Configuration has syntax errors"
    hyprctl reload
else
    echo "✅ Configuration syntax is valid"
fi

# Check required packages
echo
echo "Checking required packages..."
required_packages=(
    "hyprland"
    "hypridle"
    "hyprlock"
    "waybar"
    "mako"
    "swww"
    "wl-clipboard"
    "cliphist"
)

for package in "${required_packages[@]}"; do
    if pacman -Qi "$package" &> /dev/null; then
        echo "✅ $package is installed"
    else
        echo "❌ $package is not installed"
    fi
done

# Check scripts
echo
echo "Checking utility scripts..."
script_dir="$HOME/.config/hypr/scripts"
if [[ -d "$script_dir" ]]; then
    script_count=$(find "$script_dir" -name "*.sh" -o -name "*.py" | wc -l)
    echo "✅ Found $script_count utility scripts"
else
    echo "❌ Scripts directory not found"
fi

echo
echo "=== Validation Complete ==="
