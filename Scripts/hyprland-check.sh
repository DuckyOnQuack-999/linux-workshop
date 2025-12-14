#!/bin/bash

# Color definitions
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

# Icons
ICON_CHECK="✓"
ICON_ERROR="✗"
ICON_WARN="⚠"
ICON_INFO="ℹ"

# Function to display header
print_header() {
    echo -e "\n${BLUE}=== Hyprland System Check ===${NC}"
    echo -e "${YELLOW}Important Notes:${NC}"
    echo -e "• Hyprland dots are maintained in a separate repository"
    echo -e "• Configurations are constantly evolving - check changelogs"
    echo -e "• Some screenshots may be outdated"
    echo -e "• Wallpapers are from a separate repository\n"
}

# Function to check system requirements
check_requirements() {
    echo -e "${CYAN}${ICON_INFO} System Requirements Check:${NC}"
    
    # Check for backup tools
    if command -v snapper >/dev/null || command -v timeshift >/dev/null; then
        echo -e "${GREEN}${ICON_CHECK} Backup tool detected${NC}"
    else
        echo -e "${RED}${ICON_ERROR} No backup tool found - Please install snapper or timeshift${NC}"
    fi
    
    # Check for pipewire
    if systemctl --user is-active pipewire >/dev/null 2>&1; then
        echo -e "${GREEN}${ICON_CHECK} Pipewire is active${NC}"
    else
        echo -e "${YELLOW}${ICON_WARN} Pipewire not detected - Required for audio${NC}"
    fi
    
    # Check for NVIDIA GPU
    if lspci | grep -i nvidia >/dev/null; then
        echo -e "${YELLOW}${ICON_WARN} NVIDIA GPU detected - Additional configuration required:${NC}"
        echo -e "  • Check WLR_DRM_DEVICES configuration"
        echo -e "  • Verify nvidia-drm module settings"
        echo -e "  • For GTX 900 and newer, nvidia-dkms will be installed"
    fi
    
    # Check for base-devel
    if pacman -Qi base-devel >/dev/null 2>&1; then
        echo -e "${GREEN}${ICON_CHECK} base-devel is installed${NC}"
    else
        echo -e "${RED}${ICON_ERROR} base-devel not found - Required for installation${NC}"
    fi
    
    # Check shell configuration
    if [ "$SHELL" = "/usr/bin/zsh" ]; then
        echo -e "${GREEN}${ICON_CHECK} ZSH is configured as default shell${NC}"
    else
        echo -e "${YELLOW}${ICON_WARN} ZSH is not your default shell - Consider switching:${NC}"
        echo -e "  Run: chsh -s \$(which zsh)"
    fi
}

# Function to display prerequisites
show_prerequisites() {
    echo -e "\n${CYAN}${ICON_INFO} Prerequisites:${NC}"
    echo -e "• Minimal Arch Linux installation (server/minimal type)"
    echo -e "• Internet connection"
    echo -e "• Base-devel package group"
    echo -e "• Git package installed"
    echo -e "• Write permissions in installation directory"
}

# Main execution
print_header
check_requirements
show_prerequisites

echo -e "\n${YELLOW}${ICON_WARN} Important:${NC}"
echo -e "• Back up your system before proceeding with installation"
echo -e "• No uninstallation script is provided to prevent system damage"
echo -e "• Some packages may already be installed by your distribution"

read -n 1 -s -r -p "Press any key to continue..." 