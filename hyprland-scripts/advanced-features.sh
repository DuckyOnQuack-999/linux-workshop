#!/usr/bin/env bash
set -euo pipefail

# Advanced Hyprland Features Manager
# This script provides additional functionality from hyprland-advanced-extras.sh

log_info() {
    echo -e "$(date "+%Y-%m-%d %H:%M:%S") [INFO] $1"
}

log_success() {
    echo -e "$(date "+%Y-%m-%d %H:%M:%S") [SUCCESS] $1"
}

log_error() {
    echo -e "$(date "+%Y-%m-%d %H:%M:%S") [ERROR] $1"
}

# Enhanced workspace management with dynamic creation
create_dynamic_workspace() {
    local workspace_name="$1"
    local workspace_id="$2"
    
    if [[ -z "$workspace_name" || -z "$workspace_id" ]]; then
        echo "Usage: $0 create-workspace <name> <id>"
        return 1
    fi
    
    log_info "Creating dynamic workspace: $workspace_name (ID: $workspace_id)"
    hyprctl dispatch workspace "$workspace_id"
    hyprctl dispatch renameworkspace "$workspace_id" "$workspace_name"
    log_success "Workspace $workspace_name created successfully"
}

# Advanced window management with smart tiling
smart_tile_windows() {
    local direction="$1"
    
    case "$direction" in
        "horizontal"|"h")
            hyprctl dispatch layoutmsg "togglesplit"
            log_info "Toggled horizontal split"
            ;;
        "vertical"|"v")
            hyprctl dispatch layoutmsg "togglesplit"
            log_info "Toggled vertical split"
            ;;
        "master"|"m")
            hyprctl dispatch layoutmsg "cyclenext"
            log_info "Cycled to next layout"
            ;;
        *)
            echo "Usage: $0 smart-tile {horizontal|vertical|master}"
            return 1
            ;;
    esac
}

# Dynamic color scheme application
apply_dynamic_colors() {
    local wallpaper_path="$1"
    
    if [[ -z "$wallpaper_path" ]]; then
        wallpaper_path="$HOME/wallpaper.jpg"
    fi
    
    if [[ ! -f "$wallpaper_path" ]]; then
        log_error "Wallpaper not found: $wallpaper_path"
        return 1
    fi
    
    log_info "Applying dynamic colors from: $wallpaper_path"
    
    if command -v wal &> /dev/null; then
        wal -i "$wallpaper_path" -n
        log_success "Dynamic colors applied successfully"
    else
        log_error "pywal not found. Install with: pipx install pywal"
        return 1
    fi
}

# Advanced gesture configuration
configure_gestures() {
    log_info "Configuring advanced gestures..."
    
    # Enable workspace swipe gestures
    hyprctl keyword "gestures:workspace_swipe" true
    hyprctl keyword "gestures:workspace_swipe_fingers" 3
    hyprctl keyword "gestures:workspace_swipe_distance" 300
    hyprctl keyword "gestures:workspace_swipe_invert" true
    hyprctl keyword "gestures:workspace_swipe_min_speed_to_force" 30
    hyprctl keyword "gestures:workspace_swipe_cancel_ratio" 0.5
    hyprctl keyword "gestures:workspace_swipe_create_new" true
    hyprctl keyword "gestures:workspace_swipe_forever" true
    
    log_success "Advanced gestures configured"
}

# Enhanced blur effects
configure_blur() {
    local intensity="$1"
    
    if [[ -z "$intensity" ]]; then
        intensity="5"
    fi
    
    log_info "Configuring blur effects with intensity: $intensity"
    
    hyprctl keyword "decoration:blur:enabled" true
    hyprctl keyword "decoration:blur:size" "$intensity"
    hyprctl keyword "decoration:blur:passes" 3
    hyprctl keyword "decoration:blur:new_optimizations" true
    hyprctl keyword "decoration:blur:xray" true
    hyprctl keyword "decoration:blur:ignore_opacity" true
    
    log_success "Blur effects configured"
}

# Advanced window rules management
manage_window_rules() {
    local action="$1"
    local rule="$2"
    
    case "$action" in
        "add")
            if [[ -z "$rule" ]]; then
                echo "Usage: $0 manage-rules add \"<rule>\""
                return 1
            fi
            hyprctl keyword "windowrule" "$rule"
            log_success "Added window rule: $rule"
            ;;
        "list")
            hyprctl getoption "windowrule" | grep -v "int:"
            ;;
        "clear")
            hyprctl keyword "windowrule" "reset"
            log_success "Cleared all window rules"
            ;;
        *)
            echo "Usage: $0 manage-rules {add|list|clear} [rule]"
            return 1
            ;;
    esac
}

# System performance monitoring
monitor_performance() {
    log_info "Hyprland Performance Monitor"
    echo "================================"
    
    echo "Active Windows: $(hyprctl clients | grep -c "class:" || echo "0")"
    echo "Workspaces: $(hyprctl workspaces | grep -c "workspace" || echo "0")"
    echo "Monitors: $(hyprctl monitors | grep -c "Monitor" || echo "0")"
    
    echo
    echo "Memory Usage:"
    free -h | grep "Mem:"
    
    echo
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%" -f1
    
    echo
    echo "GPU Status:"
    for driver in mesa nvidia amdvlk; do
        if pacman -Qi "$driver" &> /dev/null; then
            echo "✅ $driver is installed"
        else
            echo "❌ $driver is not installed"
        fi
    done
}

# Main function
main() {
    case "$1" in
        "create-workspace")
            create_dynamic_workspace "$2" "$3"
            ;;
        "smart-tile")
            smart_tile_windows "$2"
            ;;
        "apply-colors")
            apply_dynamic_colors "$2"
            ;;
        "configure-gestures")
            configure_gestures
            ;;
        "configure-blur")
            configure_blur "$2"
            ;;
        "manage-rules")
            manage_window_rules "$2" "$3"
            ;;
        "monitor")
            monitor_performance
            ;;
        *)
            echo "Advanced Hyprland Features Manager"
            echo "=================================="
            echo
            echo "Usage: $0 {command} [options]"
            echo
            echo "Commands:"
            echo "  create-workspace <name> <id>  - Create dynamic workspace"
            echo "  smart-tile {h|v|m}            - Smart window tiling"
            echo "  apply-colors [wallpaper]      - Apply dynamic colors"
            echo "  configure-gestures            - Configure advanced gestures"
            echo "  configure-blur [intensity]    - Configure blur effects"
            echo "  manage-rules {add|list|clear} - Manage window rules"
            echo "  monitor                       - Monitor system performance"
            echo
            echo "Examples:"
            echo "  $0 create-workspace \"PROJECT\" 6"
            echo "  $0 smart-tile horizontal"
            echo "  $0 apply-colors ~/Pictures/wallpaper.jpg"
            echo "  $0 configure-blur 8"
            echo "  $0 manage-rules add \"float,class:^(pavucontrol)$\""
            echo "  $0 monitor"
            ;;
    esac
}

main "$@"
