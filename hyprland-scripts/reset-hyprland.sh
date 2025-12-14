#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/hypr"
BACKUP_DIR="$HOME/.config/hypr/backups/$(date +%Y-%m-%d_%H.%M.%S)"
INSTALL_SCRIPT="$HOME/.config/hypr/scripts/hyprland-advanced-extras-enhanced.sh"

# Backup existing configuration
backup_config() {
    if [[ -d "$CONFIG_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$CONFIG_DIR"/* "$BACKUP_DIR/" || {
            echo "Error: Failed to backup $CONFIG_DIR"
            exit 1
        }
        chmod 700 "$BACKUP_DIR"
        echo "Backed up configuration to $BACKUP_DIR"
    fi
}

# Reset configuration directory
reset_config() {
    if [[ -z "$CONFIG_DIR" || "$CONFIG_DIR" == "/" || "$CONFIG_DIR" == "$HOME" ]]; then
        echo "Error: Invalid CONFIG_DIR: $CONFIG_DIR"
        exit 1
    fi
    if [[ -d "$CONFIG_DIR" ]]; then
        backup_config
        rm -rf "$CONFIG_DIR" || {
            echo "Error: Failed to remove $CONFIG_DIR"
            exit 1
        }
        echo "Removed existing $CONFIG_DIR"
    fi
    mkdir -p "$CONFIG_DIR" || {
        echo "Error: Failed to create $CONFIG_DIR"
        exit 1
    }
    echo "Created fresh $CONFIG_DIR"
}

# Yad dialog
if command -v yad &> /dev/null; then
    yad --title="Reset Hyprland Configuration" \
        --text="This will delete all files in $CONFIG_DIR and create a fresh configuration.\n\nA backup will be created in $BACKUP_DIR.\n\nDo you want to proceed?" \
        --button="Yes:0" \
        --button="No:1" \
        --width=400 --height=200 --center
    response=$?
else
    echo "Warning: yad not found, using terminal prompt"
    read -p "This will delete all files in $CONFIG_DIR and create a fresh configuration. A backup will be created in $BACKUP_DIR. Proceed? (y/N): " response
    case "$response" in
        [yY]*) response=0 ;;
        *) response=1 ;;
    esac
fi

if [[ $response -eq 0 ]]; then
    reset_config
    if [[ -f "$INSTALL_SCRIPT" && -x "$INSTALL_SCRIPT" ]]; then
        read -p "Re-run installation script to set up new configuration? (y/N): " rerun
        if [[ "$rerun" =~ ^[yY] ]]; then
            bash "$INSTALL_SCRIPT" || {
                echo "Error: Failed to run $INSTALL_SCRIPT"
                exit 1
            }
        else
            echo "Configuration reset. Run $INSTALL_SCRIPT manually to set up new configuration."
        fi
    else
        echo "Error: Installation script not found or not executable at $INSTALL_SCRIPT"
        exit 1
    fi
else
    echo "Reset cancelled"
    exit 1
fi
