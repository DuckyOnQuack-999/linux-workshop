#!/bin/bash

# Universal Arch Proton Setup Script
# Fully automated, smart Wine conflict handling, dynamic dependency install
# Installs Steam, Proton GE, and all Windows gaming dependencies

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting universal Arch Proton setup...${NC}"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Remove a package only if installed
safe_remove() {
    PACKAGE="$1"
    if pacman -Qi "$PACKAGE" >/dev/null 2>&1; then
        echo -e "${YELLOW}Removing conflicting package: $PACKAGE${NC}"
        sudo pacman -R --noconfirm "$PACKAGE"
    fi
}

# Install a package if missing, with AUR fallback
safe_install_if_missing() {
    PACKAGE="$1"
    if pacman -Qi "$PACKAGE" >/dev/null 2>&1; then
        echo -e "${GREEN}$PACKAGE is already installed. Skipping installation.${NC}"
    else
        # Handle Wine conflict automatically
        if [[ "$PACKAGE" == "wine" ]]; then
            safe_remove "wine-staging"
        fi
        echo -e "${YELLOW}Installing package: $PACKAGE${NC}"
        if pacman -Si "$PACKAGE" >/dev/null 2>&1; then
            sudo pacman -S --needed --noconfirm "$PACKAGE"
        else
            yay -S --needed --noconfirm "$PACKAGE"
        fi
    fi
}

# Update system
echo -e "${YELLOW}Updating system...${NC}"
sudo pacman -Syu --noconfirm

# Install base-devel and git
safe_install_if_missing "base-devel"
safe_install_if_missing "git"

# Install yay if missing
if ! command_exists yay; then
    echo -e "${YELLOW}Installing yay (AUR helper)...${NC}"
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
fi

# Install Wine (smart conflict handling)
safe_install_if_missing "wine"

# Detect Steam installation
if command_exists steam; then
    STEAM_CMD="steam"
    PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
elif command_exists flatpak && flatpak list | grep -q com.valvesoftware.Steam; then
    STEAM_CMD="flatpak run com.valvesoftware.Steam"
    PROTON_DIR="$HOME/.var/app/com.valvesoftware.Steam/.steam/root/compatibilitytools.d"
else
    echo -e "${YELLOW}Steam not found. Installing system Steam...${NC}"
    safe_install_if_missing "steam"
    STEAM_CMD="steam"
    PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
fi

# Create Proton directory
mkdir -p "$PROTON_DIR"

# Windows gaming dependencies
DEPENDENCIES=(lib32-mesa lib32-vulkan-icd-loader winetricks vkd3d-proton
    dxvk-async-git lib32-FAudio lib32-vulkan-radeon lib32-vulkan-intel)

for pkg in "${DEPENDENCIES[@]}"; do
    safe_install_if_missing "$pkg"
done

# Download latest Proton GE
echo -e "${YELLOW}Downloading latest Proton GE release...${NC}"
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

PROTON_LATEST=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest |
    grep browser_download_url | grep '.tar.gz' | cut -d '"' -f 4 | head -n 1)

if [ -z "$PROTON_LATEST" ]; then
    echo -e "${RED}Failed to fetch Proton GE release. Check your internet connection.${NC}"
    exit 1
fi

wget -q "$PROTON_LATEST" -O proton-ge.tar.gz
echo -e "${GREEN}Downloaded Proton GE successfully.${NC}"

# Extract Proton GE
tar -xzf proton-ge.tar.gz -C "$PROTON_DIR"
echo -e "${GREEN}Proton GE installed in $PROTON_DIR.${NC}"

# Cleanup
rm -rf "$TEMP_DIR"

# Completion message
echo -e "${GREEN}Proton setup complete with all dependencies installed and conflicts resolved!${NC}"
echo -e "${YELLOW}To enable Proton in Steam:${NC}"
echo -e "1. Open Steam."
echo -e "2. Go to Settings -> Steam Play."
echo -e "3. Enable Steam Play for all titles."
echo -e "4. Select 'Proton - GloriousEggroll' as default."
echo -e "5. Restart Steam."
