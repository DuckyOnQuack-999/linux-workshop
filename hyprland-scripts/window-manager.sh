#!/usr/bin/env bash

# Enhanced window management functions
function tile_windows() {
    hyprctl dispatch layoutmsg "togglesplit"
    echo "Toggled window tiling"
}

function cycle_windows() {
    hyprctl dispatch cyclenext
    echo "Cycled to next window"
}

function smart_resize() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 resize <width> <height>"
        return 1
    fi
    hyprctl dispatch resizeactive "$1" "$2"
    echo "Resized window to $1x$2"
}

function close_all_windows() {
    local count=0
    while hyprctl clients | grep -q "class:"; do
        hyprctl dispatch killactive
        ((count++))
        if [[ $count -gt 50 ]]; then
            echo "Warning: Too many windows, stopping"
            break
        fi
    done
    echo "Closed all windows"
}

function move_to_workspace() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 move <workspace>"
        return 1
    fi
    hyprctl dispatch movetoworkspace "$1"
    echo "Moved window to workspace $1"
}

function toggle_floating() {
    hyprctl dispatch togglefloating
    echo "Toggled floating mode"
}

function maximize_window() {
    hyprctl dispatch fullscreen 1
    echo "Maximized window"
}

# Main logic
case "$1" in
    "tile") tile_windows ;;
    "cycle") cycle_windows ;;
    "resize") smart_resize "$2" "$3" ;;
    "close-all") close_all_windows ;;
    "move") move_to_workspace "$2" ;;
    "float") toggle_floating ;;
    "maximize") maximize_window ;;
    *) 
        echo "Usage: $0 {tile|cycle|resize|close-all|move|float|maximize}"
        echo "  tile - Toggle window tiling"
        echo "  cycle - Cycle to next window"
        echo "  resize <w> <h> - Resize window"
        echo "  close-all - Close all windows"
        echo "  move <ws> - Move to workspace"
        echo "  float - Toggle floating"
        echo "  maximize - Maximize window"
        ;;
esac
