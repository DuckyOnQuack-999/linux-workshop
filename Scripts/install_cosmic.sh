#!/usr/bin/env bash

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Script variables
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/cosmic-install-$(date +%Y%m%d-%H%M%S).log"
readonly COSMIC_DIR="$HOME/.cache/cosmic-build"
readonly BOLD="\e[1m"
readonly RED="\e[31m"
readonly GREEN="\e[32m"
readonly YELLOW="\e[33m"
readonly RESET="\e[0m"

# Dependency arrays
declare -a BUILD_DEPS=(
    "rust"
    "cargo"
    "git"
    "base-devel"
    "cmake"
    "ninja"
    "meson"
    "wayland"
    "wayland-protocols"
    "libxkbcommon"
    "pixman"
    "cairo"
    "pango"
    "gtk4"
    "libinput"
    "seatd"
    "mesa"
)

# Logging functions
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BOLD}[INFO]${RESET} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $*" | tee -a "$LOG_FILE"
}

# Progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Installation failed! Check the log file at $LOG_FILE for details."
        log_info "Cleaning up..."
        rm -rf "$COSMIC_DIR"
    fi
}

# Check system requirements
check_system() {
    log_info "Checking system requirements..."
    
    if ! command -v pacman >/dev/null 2>&1; then
        log_error "This script requires an Arch-based system with pacman."
        exit 1
    fi

    if [ "$(id -u)" = 0 ]; then
        log_error "This script should not be run as root."
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing required dependencies..."
    
    # Update package database
    sudo pacman -Sy || {
        log_error "Failed to update package database"
        exit 1
    }

    # Install build dependencies
    sudo pacman -S --needed "${BUILD_DEPS[@]}" || {
        log_error "Failed to install dependencies"
        exit 1
    }
}

# Clone and build cosmic
build_cosmic() {
    log_info "Creating build directory at $COSMIC_DIR"
    mkdir -p "$COSMIC_DIR"
    cd "$COSMIC_DIR"

    # Clone repositories with proper error handling
    log_info "Cloning COSMIC repositories..."
    
    # Clone main cosmic repository
    git clone -b master_jammy https://github.com/pop-os/cosmic.git || {
        log_error "Failed to clone cosmic repository"
        return 1
    }
    
    # Clone and checkout other repositories
    declare -A repos=(
        ["cosmic-comp"]="master"
        ["cosmic-panel"]="master"
        ["cosmic-applets"]="master"
        ["cosmic-launcher"]="master"
    )

    for repo in "${!repos[@]}"; do
        branch="${repos[$repo]}"
        log_info "Cloning $repo ($branch branch)..."
        
        git clone -b "$branch" "https://github.com/pop-os/$repo.git" || {
            log_error "Failed to clone $repo repository"
            return 1
        }
    done

    # Verify repository structure
    for repo in cosmic cosmic-comp cosmic-panel cosmic-applets cosmic-launcher; do
        if [ ! -d "$COSMIC_DIR/$repo" ]; then
            log_error "Repository directory $repo not found"
            return 1
        fi
        
        if [ ! -f "$COSMIC_DIR/$repo/Cargo.toml" ]; then
            log_error "Cargo.toml not found in $repo"
            return 1
        fi
    done

    # Build components
    log_info "Building COSMIC components..."
    
    for repo in cosmic cosmic-comp cosmic-panel cosmic-applets cosmic-launcher; do
        log_info "Building $repo..."
        cd "$COSMIC_DIR/$repo"
        
        # Update dependencies
        cargo fetch || {
            log_error "Failed to fetch dependencies for $repo"
            return 1
        }
        
        # Build with release profile
        cargo build --release || {
            log_error "Failed to build $repo"
            return 1
        }
        
        log_success "Successfully built $repo"
    done

    return 0
}

# Setup cosmic desktop
setup_desktop() {
    log_info "Setting up COSMIC desktop environment..."
    
    # Create XDG autostart directory
    mkdir -p "$HOME/.config/autostart"
    
    # Install binary files
    sudo install -Dm755 "$COSMIC_DIR"/cosmic-comp/target/release/cosmic-comp /usr/local/bin/
    sudo install -Dm755 "$COSMIC_DIR"/cosmic-panel/target/release/cosmic-panel /usr/local/bin/
    sudo install -Dm755 "$COSMIC_DIR"/cosmic-launcher/target/release/cosmic-launcher /usr/local/bin/
    
    log_success "COSMIC desktop environment installed successfully!"
}

# Main execution
main() {
    # Print banner
    echo -e "${BOLD}COSMIC Desktop Installer v${SCRIPT_VERSION}${RESET}"
    echo -e "===============================\n"
    # Set up cleanup trap
    trap cleanup EXIT

    # Start installation process
    check_system
    install_dependencies
    build_cosmic
    setup_desktop

    log_success "Installation completed successfully!"
    log_info "Log file is available at: $LOG_FILE"
    log_info "Please logout and select COSMIC from your display manager to start using it."
}

# Run main function
main "$@"

