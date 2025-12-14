#!/usr/bin/env bash

# Enhanced close all windows with confirmation
echo "Closing all windows..."

# Count windows before closing
window_count=$(hyprctl clients | grep -c "class:" || echo "0")

if [[ $window_count -eq 0 ]]; then
    echo "No windows to close"
    exit 0
fi

echo "Found $window_count windows"

# Close all windows
count=0
while hyprctl clients | grep -q "class:"; do
    hyprctl dispatch killactive
    ((count++))
    if [[ $count -gt 50 ]]; then
        echo "Warning: Too many windows, stopping"
        break
    fi
done

echo "Closed $count windows"
