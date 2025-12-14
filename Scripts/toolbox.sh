#!/bin/bash

# Script version and metadata
VERSION="1.0.0"
AUTHOR="duckyonquack999"
GITHUB_URL="https://github.com/duckyonquack999"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Debug: Script directory is $SCRIPT_DIR"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Icons for status messages
ICON_CHECK="✓"
ICON_ERROR="✗"
ICON_WARN="⚠"
ICON_INFO="ℹ"
ICON_SYSTEM="🖥"
ICON_NETWORK="🌐"
ICON_SECURITY="🔒"
ICON_BACKUP="💾"
ICON_UPDATE="🔄"
ICON_PACKAGE="📦"
ICON_COMPLETE="🎉"

# Initialize script state
echo "Debug: Initializing script state"

# Global error handling
set -o pipefail

# Configuration paths
LOG_DIR="${HOME}/.local/share/toolbox/logs"
BACKUP_DIR="${HOME}/.local/backup"
CONFIG_FILE="${SCRIPT_DIR}/.toolbox_config"
MAX_LOG_SIZE=10  # in MB

# Initialize arrays for monitoring
declare -A CPU_HISTORY
declare -A MEM_HISTORY

# Configuration arrays
IMPORTANT_CONFIGS=(
    "$HOME/.config/hypr"
    "$HOME/.config/kde"
    "$HOME/.config/environment.d"
    "$HOME/.config/plasma-workspace"
    "$HOME/.config/kwinrc"
    "$HOME/.config/waybar"
    "$HOME/.config/wlogout"
    "/etc/X11/xorg.conf.d"
)

declare -A PACKAGE_MANAGERS
PACKAGE_MANAGERS=(
    ["pacman"]="/var/lib/pacman/db.lck"
    ["yay"]="${HOME}/.cache/yay/db.lck"
    ["paru"]="${HOME}/.cache/paru/db.lck"
)

# Update settings
UPDATE_URL="https://raw.githubusercontent.com/yourusername/dotfiles/main/Linux/Scripts/toolbox.sh"
GITHUB_API="https://api.github.com/repos/yourusername/dotfiles"
AUTO_UPDATE_CHECK=true
LAST_UPDATE_CHECK=0
UPDATE_CHECK_INTERVAL=86400 # 24 hours in seconds
MONITOR_INTERVAL=5

# Source utility functions
UTILS_DIR="$SCRIPT_DIR/functions"
echo "Debug: Attempting to source utility functions from $UTILS_DIR"

# Create functions directory if it doesn't exist
if [ ! -d "$UTILS_DIR" ]; then
    echo "Debug: Creating functions directory"
    mkdir -p "$UTILS_DIR"
fi

# List contents of functions directory
echo "Debug: Contents of $UTILS_DIR:"
ls -la "$UTILS_DIR"

# Source each utility file
for util in gpu_utils.sh network_utils.sh cleanup_utils.sh; do
    util_path="$UTILS_DIR/$util"
    echo "Debug: Checking for $util at $util_path"
    
    if [ -f "$util_path" ]; then
        echo "Debug: Found $util, sourcing it"
        source "$util_path"
        echo "Debug: Successfully sourced $util"
    else
        echo -e "${RED}${ICON_ERROR} Utility not found: $util_path${NC}"
            exit 1
        fi
done

# Helper functions
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           $1           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"
}

print_menu_item() {
    echo -e "${GREEN}$1.${NC} $2"
}

confirm_action() {
    local prompt=$1
    while true; do
        read -r -p "$prompt [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]|"") return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Main menu function
show_menu() {
    clear
    print_header "System Toolbox Menu"
    echo
    
    # Get system status with error handling
        local cpu_usage
    local mem_usage
        local disk_usage
    
    cpu_usage=$(get_cpu_usage)
    mem_usage=$(get_memory_usage)
    disk_usage=$(get_disk_usage)
    
    echo "System Status"
    echo "CPU: ${cpu_usage}% | Memory: ${mem_usage}% | Disk: ${disk_usage}%"
    echo
    
    echo "System Management"
    print_menu_item "1" "System Maintenance"
    print_menu_item "2" "System Update & Backup"
    print_menu_item "3" "System Health Check"
    print_menu_item "4" "Network Diagnostics"
    print_menu_item "5" "Security Audit"
    echo
    
    echo "Desktop Environment"
    print_menu_item "6" "Detect Theme"
    print_menu_item "7" "Install HyDE"
    print_menu_item "8" "Update HyDE"
    print_menu_item "9" "Verify HyDE"
    print_menu_item "10" "Install Hyprland Base"
    print_menu_item "11" "Install Hyprland Advanced"
    print_menu_item "12" "Install Hyprland Productivity"
    print_menu_item "13" "Hyprland All Extras"
    print_menu_item "14" "Hyprland All-in-One Update"
    echo
    
    echo "Storage Management"
    print_menu_item "15" "NTFS Mounter"
    print_menu_item "16" "NTFS Status"
    print_menu_item "17" "Backup Configs"
    echo
    
    echo "Development Tools"
    print_menu_item "18" "GitHub Repos Scanner"
    print_menu_item "19" "Desktop Environment Manager"
    print_menu_item "20" "Super Rice System"
    echo
    
    echo "System Information"
    print_menu_item "21" "GPU Information"
    print_menu_item "22" "Hardware Acceleration"
    print_menu_item "23" "System Updates Check"
    echo
    
    echo "Advanced Options"
    print_menu_item "24" "Power Management"
    print_menu_item "25" "System Cleanup"
    print_menu_item "26" "Security Check"
    print_menu_item "27" "View Logs"
    echo
    
    echo "Help & Exit"
    print_menu_item "h" "Show Help"
    print_menu_item "0" "Exit"
    echo
    
    read -r -p "Please enter your choice: " choice
    handle_menu_choice "$choice"
}

# System monitoring functions
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' || echo "N/A"
}

get_memory_usage() {
    free | grep Mem | awk '{print int($3/$2 * 100)}' || echo "N/A"
}

get_disk_usage() {
    df -h / | tail -n 1 | awk '{print int($5)}' || echo "N/A"
}

# Menu choice handler
handle_menu_choice() {
    local choice=$1
    case $choice in
        1) system_maintenance ;;
        2) system_update_backup ;;
        3) system_health_check ;;
        4) network_diagnostics ;;
        5) security_audit ;;
        6) detect_theme ;;
        7) install_hyde ;;
        8) update_hyde ;;
        9) verify_hyde ;;
        10) install_hyprland_base ;;
        11) install_hyprland_advanced ;;
        12) install_hyprland_productivity ;;
        13) install_hyprland_extras ;;
        14) hyprland_update_all ;;
        15) ntfs_mounter ;;
        16) ntfs_status ;;
        17) backup_configs ;;
        18) github_repos_scanner ;;
        19) desktop_environment_manager ;;
        20) super_rice_system ;;
        21) gpu_information ;;
        22) hardware_acceleration ;;
        23) system_updates_check ;;
        24) power_management ;;
        25) system_cleanup ;;
        26) security_check ;;
        27) view_logs ;;
        h|H) show_help ;;
        0|q|Q) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    
    if [ "$choice" != "0" ] && [ "$choice" != "q" ] && [ "$choice" != "Q" ]; then
        read -r -p "Press Enter to continue..."
        show_menu
    fi
}

# System maintenance function
system_maintenance() {
    while true; do
        print_header "System Maintenance"
        
        echo "System Maintenance Options:"
        echo "1. System Cleanup"
        echo "2. Package Cache Cleanup"
        echo "3. Log Rotation"
        echo "4. Service Management"
        echo "5. Disk Management"
        echo "0. Back to Main Menu"
        echo
        
        read -r -p "Please select an option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}${ICON_SYSTEM} Performing system cleanup...${NC}"
                if command -v paccache &> /dev/null; then
                    sudo paccache -r
                else
                    echo -e "${YELLOW}${ICON_WARN} paccache not found. Skipping package cache cleanup.${NC}"
                fi
                
                if pacman -Qtdq &> /dev/null; then
                    sudo pacman -Rns $(pacman -Qtdq)
                else
                    echo -e "${GREEN}${ICON_CHECK} No orphaned packages found.${NC}"
                fi
                
                echo -e "${BLUE}${ICON_SYSTEM} Cleaning home directory...${NC}"
                rm -rf ~/.cache/thumbnails/* ~/.local/share/Trash/* 2>/dev/null
                ;;
                
            2)
                echo -e "${BLUE}${ICON_PACKAGE} Cleaning package cache...${NC}"
                if command -v paccache &> /dev/null; then
                    sudo paccache -rk1
                    echo -e "${GREEN}${ICON_CHECK} Package cache cleaned.${NC}"
                else
                    echo -e "${RED}${ICON_ERROR} paccache not found.${NC}"
                fi
                ;;
                
            3)
                echo -e "${BLUE}${ICON_SYSTEM} Rotating system logs...${NC}"
                if command -v journalctl &> /dev/null; then
                    sudo journalctl --vacuum-time=7d
                    echo -e "${GREEN}${ICON_CHECK} System logs cleaned.${NC}"
                else
                    echo -e "${RED}${ICON_ERROR} journalctl not found.${NC}"
                fi
                ;;
                
            4)
                echo -e "${BLUE}${ICON_SYSTEM} Checking system services...${NC}"
                systemctl --failed
                echo
                read -r -p "Would you like to see all running services? [y/N] " response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    systemctl list-units --type=service --state=running
                fi
                ;;
                
            5)
                echo -e "${BLUE}${ICON_SYSTEM} Disk Management${NC}"
                echo "Available disks:"
                lsblk
                echo
                read -r -p "Enter disk to check (e.g., sda): " disk
                if [[ -n "$disk" ]]; then
                    if command -v smartctl &> /dev/null; then
                        sudo smartctl -H "/dev/$disk"
                    else
                        echo -e "${RED}${ICON_ERROR} smartctl not found. Please install smartmontools.${NC}"
                    fi
                fi
                ;;
                
            0)
                return
                ;;
                
            *)
                echo -e "${RED}${ICON_ERROR} Invalid option${NC}"
            ;;
    esac
    
        if [ "$choice" != "0" ]; then
            read -r -p "Press Enter to continue..."
        fi
    done
}

# Main script execution
show_menu
