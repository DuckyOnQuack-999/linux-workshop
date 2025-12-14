#!/bin/bash

# Combined Hyprland Extras Installation Script
# This script combines functionality from:
# - hyprland-extras.sh
# - hyprland-advanced-extras.sh
# - hyprland-productivity-extras.sh

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'  # No Color
BLUE='\033[0;34m'

# Error handling
set -e
trap 'echo -e "${RED}Error: Script failed on line $LINENO${NC}"; exit 1' ERR

# Helper function for package installation
install_package() {
    if ! paru -Q "$1" &>/dev/null; then
        echo -e "${BLUE}Installing $1...${NC}"
        paru -S --noconfirm "$1"
        echo -e "${GREEN}Successfully installed $1${NC}"
    else
        echo -e "${GREEN}$1 is already installed${NC}"
    fi
}

echo -e "${BLUE}Starting Hyprland comprehensive extras installation...${NC}"

# Basic Dependencies
echo -e "\n${GREEN}Installing basic dependencies...${NC}"
install_package "python"
install_package "python-pip"
install_package "git"
install_package "base-devel"
install_package "wget"

# Core Functionality Packages
echo -e "\n${GREEN}Installing core functionality packages...${NC}"
install_package "hyprpicker"
install_package "grimblast-git"
install_package "slurp"
install_package "swappy"
install_package "cliphist"
install_package "wl-clipboard"
install_package "waybar-hyprland"
install_package "wofi"
install_package "wlogout"
install_package "swaylock-effects"
install_package "pamixer"
install_package "pavucontrol"
install_package "networkmanager"
install_package "network-manager-applet"
install_package "bluez"
install_package "bluez-utils"
install_package "blueman"

# Advanced Functionality
echo -e "\n${GREEN}Installing advanced functionality packages...${NC}"
install_package "hyprpaper"
install_package "swaybg"
install_package "waybar-hyprland-git"
install_package "wf-recorder"
install_package "grim"
install_package "imagemagick"
install_package "swayidle"
install_package "brightnessctl"
install_package "qt5-wayland"
install_package "qt6-wayland"

# Productivity Tools
echo -e "\n${GREEN}Installing productivity packages...${NC}"
install_package "ranger"
install_package "neovim"
install_package "kitty"
install_package "alacritty"
install_package "thunar"
install_package "thunar-archive-plugin"
install_package "file-roller"
install_package "starship"
install_package "exa"
install_package "bat"
install_package "ripgrep"
install_package "fd"
install_package "fzf"
install_package "zsh"
install_package "htop"
install_package "btop"

# Media and Entertainment
echo -e "\n${GREEN}Installing media packages...${NC}"
install_package "mpv"
install_package "imv"
install_package "spotify"
install_package "vlc"

# System Configuration
echo -e "\n${GREEN}Configuring system settings...${NC}"

# Enable necessary services
echo "Enabling Bluetooth service..."
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service

# Configure environment
echo "Configuring environment variables..."
echo "QT_QPA_PLATFORM=wayland" | sudo tee -a /etc/environment
echo "QT_QPA_PLATFORMTHEME=qt5ct" | sudo tee -a /etc/environment
echo "MOZ_ENABLE_WAYLAND=1" | sudo tee -a /etc/environment

# Create necessary directories
echo "Creating required directories..."
mkdir -p ~/.config/{hypr,waybar,wofi,swaylock,wlogout}
mkdir -p ~/Pictures/Screenshots

# Set up default configurations if they don't exist
if [ ! -f ~/.config/hypr/hyprland.conf ]; then
    echo "Creating default Hyprland configuration..."
    # Add your default hyprland.conf content here
fi

# Final setup and cleanup
echo -e "\n${GREEN}Performing final setup...${NC}"

# Update font cache
fc-cache -f

# Final message
echo -e "\n${GREEN}Installation Complete!${NC}"
echo -e "${BLUE}Please log out and back in for all changes to take effect.${NC}"
echo -e "${BLUE}You may need to configure individual applications to your preferences.${NC}"

