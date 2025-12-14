#!/usr/bin/env bash

# System maintenance script for Hyprland
echo "=== Hyprland System Maintenance ==="
echo

# Clean up old logs
echo "Cleaning up logs..."
if [[ -d "$HOME/.cache/hyprland" ]]; then
    find "$HOME/.cache/hyprland" -name "*.log" -mtime +7 -delete
    echo "✅ Cleaned old Hyprland logs"
fi

# Clean up old wallpapers cache
echo "Cleaning up wallpaper cache..."
if [[ -d "$HOME/.cache/wal" ]]; then
    find "$HOME/.cache/wal" -name "*.jpg" -mtime +30 -delete
    echo "✅ Cleaned old wallpaper cache"
fi

# Update package database
echo "Updating package database..."
yay -Sy &> /dev/null
echo "✅ Package database updated"

# Check for updates
echo "Checking for updates..."
updates=$(yay -Qu | wc -l)
if [[ $updates -gt 0 ]]; then
    echo "⚠️  $updates packages have updates available"
    echo "   Run 'yay -Syu' to update"
else
    echo "✅ All packages are up to date"
fi

# Check disk usage
echo
echo "Checking disk usage..."
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $disk_usage -gt 80 ]]; then
    echo "⚠️  Disk usage is high: ${disk_usage}%"
else
    echo "✅ Disk usage is normal: ${disk_usage}%"
fi

echo
echo "=== Maintenance Complete ==="
