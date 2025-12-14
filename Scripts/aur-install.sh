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
ICON_PACKAGE="📦"
ICON_INFO="ℹ"

# Function to check dependencies
check_deps() {
    local missing_deps=()
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    # Check for base-devel
    if ! pacman -Qi base-devel >/dev/null 2>&1; then
        missing_deps+=("base-devel")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}${ICON_WARN} Missing required packages: ${missing_deps[*]}${NC}"
        read -r -p "Would you like to install them? (y/n) " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo pacman -S --needed "${missing_deps[@]}" || {
                echo -e "${RED}${ICON_ERROR} Failed to install dependencies${NC}"
                exit 1
            }
        else
            echo -e "${RED}${ICON_ERROR} Dependencies are required to proceed${NC}"
            exit 1
        fi
    fi
}

# Function to install AUR package
install_package() {
    local package="$1"
    local temp_dir="/tmp/aur-${package}"
    
    echo -e "\n${CYAN}${ICON_PACKAGE} Installing AUR package: ${package}${NC}"
    
    # Create and enter temporary directory
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    cd "$temp_dir" || {
        echo -e "${RED}${ICON_ERROR} Failed to create temporary directory${NC}"
        exit 1
    }
    
    # Clone AUR repository
    echo -e "${BLUE}Cloning AUR repository...${NC}"
    if ! git clone "https://aur.archlinux.org/${package}.git" .; then
        echo -e "${RED}${ICON_ERROR} Failed to clone AUR repository${NC}"
        cd - >/dev/null
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Show PKGBUILD and ask for confirmation
    echo -e "\n${YELLOW}${ICON_WARN} Please review the PKGBUILD:${NC}"
    cat PKGBUILD
    echo
    read -r -p "Would you like to proceed with installation? (y/n) " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled by user${NC}"
        cd - >/dev/null
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Build and install package
    echo -e "${BLUE}Building and installing package...${NC}"
    if ! makepkg -si; then
        echo -e "${RED}${ICON_ERROR} Failed to build/install package${NC}"
        cd - >/dev/null
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$temp_dir"
    echo -e "${GREEN}${ICON_CHECK} Successfully installed ${package}${NC}"
}

# Main execution
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: $0 <package-name>${NC}"
    exit 1
fi

check_deps
install_package "$1" 