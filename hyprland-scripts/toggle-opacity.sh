#!/usr/bin/env bash

# Toggle window opacity with status feedback
current_active=$(hyprctl getoption decoration:active_opacity | grep -o 'float: [0-9.]*' | cut -d' ' -f2)
current_inactive=$(hyprctl getoption decoration:inactive_opacity | grep -o 'float: [0-9.]*' | cut -d' ' -f2)

if (( $(echo "$current_active < 1.0" | bc -l) )); then
    # Currently transparent, make opaque
    hyprctl keyword decoration:active_opacity 1.0
    hyprctl keyword decoration:inactive_opacity 1.0
    echo "Windows made opaque"
else
    # Currently opaque, make transparent
    hyprctl keyword decoration:active_opacity 0.95
    hyprctl keyword decoration:inactive_opacity 0.85
    echo "Windows made transparent"
fi
