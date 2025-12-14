#!/usr/bin/env bash

# Toggle blur effect with status feedback
current_state=$(hyprctl getoption decoration:blur:enabled | grep -o 'int: [01]' | cut -d' ' -f2)

if [[ "$current_state" == "1" ]]; then
    hyprctl keyword decoration:blur:enabled false
    echo "Blur disabled"
else
    hyprctl keyword decoration:blur:enabled true
    echo "Blur enabled"
fi
