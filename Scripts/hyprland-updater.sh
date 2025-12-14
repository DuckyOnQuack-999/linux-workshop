#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
ICON_CHECK="✓"
ICON_WARN="⚠️"
ICON_ERROR="❌"
ICON_PACKAGE="📦"
ICON_UPDATE="🔄"
ICON_CONFIG="⚙️"

# Script version
VERSION="1.0.0"

# Log file
LOG_DIR="$HOME/.local/share/hyprland-updater"
LOG_FILE="$LOG_DIR/update.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    local deps=(
        "yay"
        "git"
        "hyprctl"
        "waybar"
        "wofi"
        "dunst"
        "kitty"
    )

    echo -e "\n${BLUE}Checking dependencies...${NC}"
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
            echo -e "${YELLOW}${ICON_WARN} Missing: $dep${NC}"
        else
            echo -e "${GREEN}${ICON_CHECK} Found: $dep${NC}"
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Installing missing dependencies...${NC}"
        yay -S --needed --noconfirm "${missing_deps[@]}" || {
            echo -e "${RED}${ICON_ERROR} Failed to install dependencies${NC}"
            log_message "ERROR" "Failed to install dependencies"
            return 1
        }
    fi
}

# Function to backup configurations
backup_configs() {
    local backup_dir="$HOME/.config/hyprland-backup-$(date +%Y%m%d-%H%M%S)"
    echo -e "\n${BLUE}${ICON_CONFIG} Backing up configurations to $backup_dir${NC}"
    
    mkdir -p "$backup_dir"
    
    local configs=(
        "$HOME/.config/hypr"
        "$HOME/.config/waybar"
        "$HOME/.config/wofi"
        "$HOME/.config/dunst"
        "$HOME/.config/kitty"
    )

    for config in "${configs[@]}"; do
        if [ -d "$config" ]; then
            cp -r "$config" "$backup_dir/" && \
            echo -e "${GREEN}${ICON_CHECK} Backed up: $config${NC}" || \
            echo -e "${RED}${ICON_ERROR} Failed to backup: $config${NC}"
        fi
    done
}

# Function to update Hyprland
update_hyprland() {
    echo -e "\n${CYAN}${ICON_UPDATE} Updating Hyprland...${NC}"
    
    local packages=(
        "hyprland-git"
        "xdg-desktop-portal-hyprland-git"
        "waybar-hyprland-git"
        "hyprpaper-git"
        "hyprpicker-git"
    )

    for pkg in "${packages[@]}"; do
        echo -e "${BLUE}Updating $pkg...${NC}"
        yay -S --needed --noconfirm "$pkg" || {
            echo -e "${RED}${ICON_ERROR} Failed to update $pkg${NC}"
            log_message "ERROR" "Failed to update $pkg"
            return 1
        }
    done
}

# Function to update Hyprland plugins
update_plugins() {
    echo -e "\n${CYAN}${ICON_UPDATE} Updating Hyprland plugins...${NC}"
    
    local plugins=(
        "hyprland-plugins-git"
        "hyprland-autoname-workspaces-git"
        "hyprland-virtual-desktops-git"
    )

    for plugin in "${plugins[@]}"; do
        echo -e "${BLUE}Updating $plugin...${NC}"
        yay -S --needed --noconfirm "$plugin" || {
            echo -e "${RED}${ICON_ERROR} Failed to update $plugin${NC}"
            log_message "ERROR" "Failed to update $plugin"
            return 1
        }
    done
}

# Function to update related packages
update_related_packages() {
    echo -e "\n${CYAN}${ICON_UPDATE} Updating related packages...${NC}"
    
    local packages=(
        "wofi"
        "waybar"
        "dunst"
        "kitty"
        "swaylock-effects"
        "swayidle"
        "wlogout"
        "grim"
        "slurp"
        "wl-clipboard"
        "polkit-kde-agent"
        "xdg-desktop-portal"
        "xdg-desktop-portal-gtk"
    )

    for pkg in "${packages[@]}"; do
        echo -e "${BLUE}Updating $pkg...${NC}"
        yay -S --needed --noconfirm "$pkg" || {
            echo -e "${RED}${ICON_ERROR} Failed to update $pkg${NC}"
            log_message "ERROR" "Failed to update $pkg"
            return 1
        }
    done
}

# Function to verify installation
verify_installation() {
    echo -e "\n${BLUE}Verifying installation...${NC}"
    
    # Check if Hyprland is running
    if pgrep -x "Hyprland" >/dev/null; then
        echo -e "${GREEN}${ICON_CHECK} Hyprland is running${NC}"
    else
        echo -e "${YELLOW}${ICON_WARN} Hyprland is not running${NC}"
    fi

    # Check critical components
    local components=(
        "waybar"
        "wofi"
        "dunst"
        "kitty"
        "hyprctl"
    )

    for component in "${components[@]}"; do
        if pgrep -x "$component" >/dev/null || command -v "$component" >/dev/null; then
            echo -e "${GREEN}${ICON_CHECK} $component is available${NC}"
        else
            echo -e "${RED}${ICON_ERROR} $component is not available${NC}"
        fi
    done

    # Check Hyprland version
    if command -v hyprctl >/dev/null; then
        local version=$(hyprctl version | head -n1)
        echo -e "${GREEN}${ICON_CHECK} Hyprland version: $version${NC}"
    fi
}

# Function to show update summary
show_summary() {
    echo -e "\n${CYAN}=== Update Summary ===${NC}"
    echo -e "${GREEN}${ICON_CHECK} Configurations backed up${NC}"
    echo -e "${GREEN}${ICON_CHECK} Hyprland core updated${NC}"
    echo -e "${GREEN}${ICON_CHECK} Plugins updated${NC}"
    echo -e "${GREEN}${ICON_CHECK} Related packages updated${NC}"
    echo -e "\nLog file: $LOG_FILE"
}

# Main update process
main() {
    echo -e "${CYAN}=== Hyprland All-in-One Updater v$VERSION ===${NC}"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}${ICON_ERROR} Please do not run this script as root${NC}"
        exit 1
    }

    # Backup configurations
    backup_configs || exit 1

    # Check and install dependencies
    check_dependencies || exit 1

    # Update Hyprland
    update_hyprland || exit 1

    # Update plugins
    update_plugins || exit 1

    # Update related packages
    update_related_packages || exit 1

    # Verify installation
    verify_installation

    # Show summary
    show_summary

    echo -e "\n${GREEN}Update complete! Please restart Hyprland to apply changes.${NC}"
    log_message "INFO" "Update completed successfully"
}

# Run main function
main 