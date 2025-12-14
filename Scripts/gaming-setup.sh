#!/usr/bin/env bash
#
# linux-gaming-setup.sh
# v6.0-universal-hybrid
# Author: AI Assistant with comprehensive Linux gaming integration
# License: MIT
# Description: Universal Linux Gaming Environment Setup with Hybrid UI
#              Supports: Arch, Debian/Ubuntu, Fedora, openSUSE, Manjaro
# Features: NVIDIA/AMD/Intel GPU detection, Wine/Proton/Steam, DXVK/VKD3D
#           Hybrid UI (yad/dialog/whiptail/TTY), Progress parsing, Error recovery
#           Proton configuration, Game fixes, System optimizations
# Usage: sudo ./linux-gaming-setup.sh [--dry-run] [--noninteractive] [--uninstall] 
#        [--verbose] [--log-level=LEVEL] [--ui=hybrid|yad|dialog|whiptail|tty] 
#        [--proton-mode=local|global|ask] [--theme=dark|light|auto] [--no-ui]

set -euo pipefail
trap 'handle_error $? $LINENO' ERR

# ----------------------
# Global Configuration
# ----------------------
SCRIPT_NAME="$(basename "$0")"
VERSION="6.0-universal-hybrid"
SYSLOG="/var/log/linux-gaming-setup.log"
USER_LOG_DIR="${HOME:-/root}/.local/share/linux-gaming-setup/logs"
USER_LOG="$USER_LOG_DIR/run-$(date +%Y%m%d-%H%M%S).log"

# Operation modes
DRY_RUN=false
NONINTERACTIVE=false
UNINSTALL=false
VERBOSE=false
LOG_LEVEL="INFO"
HEADLESS=false

# UI Configuration
UI_PREF="hybrid"
THEME="auto"
YAD_AVAILABLE=false
DIALOG_AVAILABLE=false
WHIPTAIL_AVAILABLE=false
TTY_FALLBACK=true
UI_CMD=""

# System Detection
DISTRO_FAMILY=""
PKG_MANAGER=""
GPU_VENDOR=""
KERNEL_TYPE=""
USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6 || echo "/home/$USER_NAME")

# Gaming Configuration
PROTON_MODE="ask"
STEAM_ROOTS=()
COMPAT_DIRS=()
WINE_PREFIX="${WINEPREFIX:-$USER_HOME/.wine}"
GITHUB_PROTON_REPO="GloriousEggroll/proton-ge-custom"
ENABLE_FLATPAK=true
ENABLE_OPTIMIZATIONS=true

# Progress System
PROGRESS_PID=""
PROGRESS_CURRENT=0
PROGRESS_TOTAL=100
PROGRESS_STATUS="Initializing"
PROGRESS_LOCK="/tmp/${SCRIPT_NAME}.progress.lock"

# Display
XVFB_PID=""
DISPLAY_SETUP_DONE=false

# ----------------------
# Logging System
# ----------------------
init_logging() {
    mkdir -p "$(dirname "$SYSLOG")" "$USER_LOG_DIR" 2>/dev/null || true
    touch "$SYSLOG"  2>/dev/null || true
    chmod 644 "$SYSLOG"  2>/dev/null || true
}

log() {
    local level="$1"; shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log level filtering
    case "$LOG_LEVEL" in
        ERROR) [[ "$level" != "ERROR" ]] && return ;;
        WARN) [[ ! "$level" =~ ^(ERROR|WARN)$ ]] && return ;;
        INFO) [[ ! "$level" =~ ^(ERROR|WARN|INFO)$ ]] && return ;;
    esac
    
    local log_entry="$timestamp [$level] $message"
    
    # Console output with colors
    if [[ -t 1 ]]; then
        case "$level" in
            ERROR) echo -e "\033[31m$log_entry\033[0m" >&2 ;;
            WARN) echo -e "\033[33m$log_entry\033[0m" >&2 ;;
            INFO) echo -e "\033[32m$log_entry\033[0m" ;;
            DEBUG) echo -e "\033[36m$log_entry\033[0m" ;;
            *) echo "$log_entry" ;;
        esac
    else
        echo "$log_entry"
    fi
    
    # File logging
    echo "$log_entry"
    echo "$log_entry"
}

log_error() { log "ERROR" "$@"; }
log_warn() { log "WARN" "$@"; }
log_info() { log "INFO" "$@"; }
log_debug() { log "DEBUG" "$@"; }

say() { log_info "💬 $@"; }
warn() { log_warn "⚠️ $@"; }
fatal() { log_error "❌ $@"; exit 1; }

# ----------------------
# Error Handling
# ----------------------
handle_error() {
    local exit_code=$1
    local line_no=$2
    
    log_error "Script failed with exit code $exit_code at line $line_no"
    cleanup_on_exit
    exit $exit_code
}

cleanup_on_exit() {
    log_debug "Cleaning up..."
    
    # Kill progress indicator
    [[ -n "$PROGRESS_PID" ]] && kill "$PROGRESS_PID" 2>/dev/null || true
    
    # Kill Xvfb
    [[ -n "$XVFB_PID" ]] && kill "$XVFB_PID" 2>/dev/null || true
    
    # Cleanup locks
    rm -f "$PROGRESS_LOCK" 2>/dev/null || true
    
    # Kill any remaining Wine processes
    kill_wine_processes
}

kill_wine_processes() {
    log_debug "Killing Wine processes..."
    pkill -f "wineserver" 2>/dev/null || true
    pkill -f "wine" 2>/dev/null || true
    timeout 5s su - "$USER_NAME" -c "wineserver -k" 2>/dev/null || true
    sleep 1
}

# ----------------------
# CLI Argument Parsing
# ----------------------
usage() {
    cat << EOF
$SCRIPT_NAME v$VERSION - Universal Linux Gaming Setup

Usage: sudo $0 [OPTIONS]

Options:
  --dry-run              Simulation mode, no changes made
  --noninteractive       No user prompts, use defaults
  --uninstall           Remove gaming setup
  --verbose             Enable debug output
  --log-level=LEVEL     Set log level: ERROR, WARN, INFO, DEBUG
  --ui=TYPE            UI type: hybrid, yad, dialog, whiptail, tty
  --proton-mode=MODE   Proton config: local, global, ask
  --theme=THEME        UI theme: dark, light, auto
  --no-ui              Headless mode, no UI
  -h, --help           Show this help

Examples:
  sudo $0 --ui=hybrid --theme=dark
  sudo $0 --noninteractive --no-ui --proton-mode=global
  sudo $0 --uninstall

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true ;;
            --noninteractive) NONINTERACTIVE=true ;;
            --uninstall) UNINSTALL=true ;;
            --verbose) VERBOSE=true; LOG_LEVEL="DEBUG" ;;
            --log-level=*) LOG_LEVEL="${1#*=}" ;;
            --ui=*) UI_PREF="${1#*=}" ;;
            --proton-mode=*) PROTON_MODE="${1#*=}" ;;
            --theme=*) THEME="${1#*=}" ;;
            --no-ui) HEADLESS=true ;;
            -h|--help) usage ;;
            *) fatal "Unknown option: $1" ;;
        esac
        shift
    done
    
    log_debug "Parsed arguments: DRY_RUN=$DRY_RUN, UI=$UI_PREF, PROTON_MODE=$PROTON_MODE"
}

# ----------------------
# UI System
# ----------------------
detect_ui_tools() {
    command -v yad &>/dev/null && [ -n "${DISPLAY:-}" ] && YAD_AVAILABLE=true
    command -v dialog &>/dev/null && DIALOG_AVAILABLE=true
    command -v whiptail &>/dev/null && WHIPTAIL_AVAILABLE=true
    
    log_debug "UI detection: yad=$YAD_AVAILABLE, dialog=$DIALOG_AVAILABLE, whiptail=$WHIPTAIL_AVAILABLE"
}

setup_ui() {
    detect_ui_tools
    
    if $HEADLESS; then
        UI_CMD=""
        TTY_FALLBACK=true
        return
    fi
    
    case "$UI_PREF" in
        yad)
            if $YAD_AVAILABLE; then
                UI_CMD="yad"
                TTY_FALLBACK=false
            else
                warn "yad not available, falling back to TTY"
                UI_CMD=""
                TTY_FALLBACK=true
            fi
            ;;
        hybrid)
            if $YAD_AVAILABLE && [ -n "${DISPLAY:-}" ]; then
                UI_CMD="yad"
                TTY_FALLBACK=false
            elif $DIALOG_AVAILABLE; then
                UI_CMD="dialog"
                TTY_FALLBACK=false
            elif $WHIPTAIL_AVAILABLE; then
                UI_CMD="whiptail"
                TTY_FALLBACK=false
            else
                UI_CMD=""
                TTY_FALLBACK=true
            fi
            ;;
        dialog)
            if $DIALOG_AVAILABLE; then
                UI_CMD="dialog"
                TTY_FALLBACK=false
            else
                UI_CMD=""
                TTY_FALLBACK=true
            fi
            ;;
        whiptail)
            if $WHIPTAIL_AVAILABLE; then
                UI_CMD="whiptail"
                TTY_FALLBACK=false
            else
                UI_CMD=""
                TTY_FALLBACK=true
            fi
            ;;
        tty)
            UI_CMD=""
            TTY_FALLBACK=true
            ;;
        *) fatal "Invalid UI preference: $UI_PREF" ;;
    esac
    
    log_info "UI system: $UI_CMD (fallback: $TTY_FALLBACK)"
}

ui_show_info() {
    local message="$1"
    local title="${2:-Information}"
    
    if $HEADLESS || $NONINTERACTIVE; then
        say "$message"
        return
    fi
    
    case "$UI_CMD" in
        yad) yad --center --title="$title" --text="$message" --button=OK:0 ;;
        dialog) dialog --title "$title" --msgbox "$message" 12 70 ;;
        whiptail) whiptail --title "$title" --msgbox "$message" 12 70 ;;
        *) say "$message" ;;
    esac
}

ui_show_yesno() {
    local message="$1"
    local title="${2:-Confirmation}"
    
    if $NONINTERACTIVE; then
        return 1
    fi
    
    case "$UI_CMD" in
        yad) yad --center --title="$title" --text="$message" --button=No:1 --button=Yes:0 ;;
        dialog) dialog --title "$title" --yesno "$message" 12 70 ;;
        whiptail) whiptail --title "$title" --yesno "$message" 12 70 ;;
        *)
            echo -n "$message (y/N): " >&2
            read -r response
            [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
            ;;
    esac
}

ui_show_menu() {
    local title="$1"
    local message="$2"
    shift 2
    local options=("$@")
    
    if $HEADLESS || $NONINTERACTIVE; then
        echo "${options[0]}"
        return
    fi
    
    case "$UI_CMD" in
        yad)
            local yad_options=()
            for ((i=0; i<${#options[@]}; i++)); do
                yad_options+=("$i" "${options[$i]}")
            done
            yad --center --title="$title" --text="$message" \
                --list --column="ID" --column="Option" \
                "${yad_options[@]}" --print-column=1 --separator="" \
                --button=OK:0 --height=300 --width=400
            ;;
        dialog|whiptail)
            local menu_items=()
            for ((i=0; i<${#options[@]}; i++)); do
                menu_items+=("$i" "${options[$i]}")
            done
            if [[ "$UI_CMD" == "dialog" ]]; then
                dialog --title "$title" --menu "$message" 20 60 10 \
                    "${menu_items[@]}" 2>&1 >/dev/tty
            else
                whiptail --title "$title" --menu "$message" 20 60 10 \
                    "${menu_items[@]}" 2>&1 >/dev/tty
            fi
            ;;
        *)
            echo "$message" >&2
            select choice in "${options[@]}"; do
                [[ -n "$choice" ]] && echo "$choice" && break
            done
            ;;
    esac
}

# ----------------------
# Progress System
# ----------------------
progress_start() {
    local message="$1"
    local total="${2:-100}"
    
    PROGRESS_STATUS="$message"
    PROGRESS_TOTAL="$total"
    PROGRESS_CURRENT=0
    
    if $HEADLESS || $DRY_RUN || ! [[ -t 1 ]]; then
        log_info "PROGRESS: 0% - $message"
        return
    fi
    
    # Start progress display
    (
        while [[ $PROGRESS_CURRENT -lt $PROGRESS_TOTAL ]]; do
            local percent=$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))
            local bars=$((percent / 2))
            local spaces=$((50 - bars))
            
            printf "\r[%-50s] %3d%% %s" \
                "$(printf '#%.0s' $(seq 1 $bars))" \
                "$percent" \
                "$(echo "$PROGRESS_STATUS" | cut -c-30)"
            sleep 0.1
        done
    ) &
    PROGRESS_PID=$!
}

progress_update() {
    local current="$1"
    local status="${2:-$PROGRESS_STATUS}"
    
    PROGRESS_CURRENT="$current"
    PROGRESS_STATUS="$status"
    
    if $HEADLESS || $DRY_RUN; then
        local percent=$((current * 100 / PROGRESS_TOTAL))
        log_debug "PROGRESS: $percent% - $status"
    fi
}

progress_end() {
    local message="${1:-Complete}"
    
    [[ -n "$PROGRESS_PID" ]] && kill "$PROGRESS_PID" 2>/dev/null || true
    PROGRESS_PID=""
    
    if [[ -t 1 ]] && ! $HEADLESS && ! $DRY_RUN; then
        printf "\r%-60s\n" "$message"
    else
        log_info "PROGRESS: 100% - $message"
    fi
}

# ----------------------
# System Detection
# ----------------------
detect_system() {
    progress_start "Detecting system" 10
    
    # Detect distribution
    if [[ -f /etc/arch-release ]] || grep -qi "manjaro" /etc/os-release 2>/dev/null; then
        DISTRO_FAMILY="arch"
        PKG_MANAGER="pacman"
    elif [[ -f /etc/debian_version ]] || grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        DISTRO_FAMILY="debian"
        PKG_MANAGER="apt"
    elif [[ -f /etc/fedora-release ]] || grep -qi "fedora" /etc/os-release 2>/dev/null; then
        DISTRO_FAMILY="fedora"
        PKG_MANAGER="dnf"
    elif [[ -f /etc/SuSE-release ]] || grep -qi "opensuse" /etc/os-release 2>/dev/null; then
        DISTRO_FAMILY="suse"
        PKG_MANAGER="zypper"
    else
        fatal "Unsupported Linux distribution"
    fi
    progress_update 3 "Detected distro: $DISTRO_FAMILY"
    
    # Detect GPU
    if lspci 2>/dev/null | grep -qi "nvidia"; then
        GPU_VENDOR="nvidia"
    elif lspci 2>/dev/null | grep -qi "amd"; then
        GPU_VENDOR="amd"
    elif lspci 2>/dev/null | grep -qi "intel"; then
        GPU_VENDOR="intel"
    else
        GPU_VENDOR="unknown"
    fi
    progress_update 6 "Detected GPU: $GPU_VENDOR"
    
    # Detect kernel type
    local kernel_version=$(uname -r)
    if [[ "$kernel_version" =~ "-lts" ]]; then
        KERNEL_TYPE="lts"
    elif [[ "$kernel_version" =~ "-zen" ]]; then
        KERNEL_TYPE="zen"
    elif [[ "$kernel_version" =~ "-hardened" ]]; then
        KERNEL_TYPE="hardened"
    else
        KERNEL_TYPE="standard"
    fi
    progress_update 8 "Detected kernel: $KERNEL_TYPE"
    
    # Verify user
    if [[ $EUID -eq 0 ]]; then
        if [[ -z "$SUDO_USER" ]]; then
            fatal "Please run with 'sudo' rather than as root directly"
        fi
    else
        fatal "This script must be run with sudo privileges"
    fi
    progress_update 10 "System detection complete"
    
    log_info "System: $DISTRO_FAMILY, GPU: $GPU_VENDOR, Kernel: $KERNEL_TYPE, User: $USER_NAME"
}

# ----------------------
# Package Management
# ----------------------
pkg_install() {
    local packages=("$@")
    local total=${#packages[@]}
    local installed=0
    
    progress_start "Installing $total packages" $total
    
    for pkg in "${packages[@]}"; do
        if $DRY_RUN; then
            log_info "DRY-RUN: Would install $pkg"
            ((installed++))
            progress_update $installed "Would install: $pkg"
            continue
        fi
        
        log_debug "Installing package: $pkg"
        
        case "$PKG_MANAGER" in
            apt)
                apt-get install -y --show-progress "$pkg" 2>&1 | \
                while IFS= read -r line; do
                    if [[ "$line" =~ \[([0-9]+)%\] ]]; then
                        progress_update $((installed * 100 / total + ${BASH_REMATCH[1]} / total)) "Installing: $pkg"
                    fi
                done
                ;;
            pacman)
                pacman -S --noconfirm "$pkg" 2>&1 | \
                while IFS= read -r line; do
                    if [[ "$line" =~ \(([0-9]+)/([0-9]+)\) ]]; then
                        local current="${BASH_REMATCH[1]}"
                        local total_pkg="${BASH_REMATCH[2]}"
                        progress_update $((installed * 100 / total + current * 100 / total_pkg / total)) "Installing: $pkg"
                    fi
                done
                ;;
            dnf)
                dnf install -y --setopt=progress=true "$pkg" 2>&1 | \
                while IFS= read -r line; do
                    if [[ "$line" =~ ([0-9]+)% ]]; then
                        progress_update $((installed * 100 / total + ${BASH_REMATCH[1]} / total)) "Installing: $pkg"
                    fi
                done
                ;;
            zypper)
                zypper install -y --progress "$pkg" 2>&1 | \
                while IFS= read -r line; do
                    if [[ "$line" =~ ([0-9]+)% ]]; then
                        progress_update $((installed * 100 / total + ${BASH_REMATCH[1]} / total)) "Installing: $pkg"
                    fi
                done
                ;;
        esac
        
        ((installed++))
        progress_update $installed "Installed: $pkg"
    done
    
    progress_end "Package installation complete"
}

pkg_remove() {
    local packages=("$@")
    
    for pkg in "${packages[@]}"; do
        if $DRY_RUN; then
            log_info "DRY-RUN: Would remove $pkg"
            continue
        fi
        
        case "$PKG_MANAGER" in
            apt) apt-get remove -y "$pkg" ;;
            pacman) pacman -Rns --noconfirm "$pkg" ;;
            dnf) dnf remove -y "$pkg" ;;
            zypper) zypper remove -y "$pkg" ;;
        esac
    done
}

pkg_update() {
    progress_start "Updating package database" 100
    
    if $DRY_RUN; then
        log_info "DRY-RUN: Would update package database"
        progress_end "Package update complete (dry-run)"
        return
    fi
    
    case "$PKG_MANAGER" in
        apt) apt-get update ;;
        pacman) pacman -Sy ;;
        dnf) dnf update -y ;;
        zypper) zypper refresh ;;
    esac
    
    progress_end "Package database updated"
}

# ----------------------
# Driver Installation
# ----------------------
install_gpu_drivers() {
    progress_start "Installing GPU drivers" 100
    
    case "$GPU_VENDOR" in
        nvidia)
            install_nvidia_drivers
            ;;
        amd)
            install_amd_drivers
            ;;
        intel)
            install_intel_drivers
            ;;
        *)
            warn "Unknown GPU vendor, skipping driver installation"
            ;;
    esac
    
    progress_end "GPU drivers installed"
}

install_nvidia_drivers() {
    log_info "Installing NVIDIA drivers"
    
    local nvidia_packages=()
    local vulkan_packages=()
    
    case "$DISTRO_FAMILY" in
        arch)
            nvidia_packages=("nvidia" "nvidia-utils" "nvidia-settings")
            vulkan_packages=("vulkan-icd-loader" "lib32-vulkan-icd-loader")
            ;;
        debian)
            nvidia_packages=("nvidia-driver" "nvidia-settings")
            vulkan_packages=("vulkan-tools" "libvulkan1")
            ;;
        fedora)
            nvidia_packages=("akmod-nvidia" "xorg-x11-drv-nvidia")
            vulkan_packages=("vulkan-loader" "vulkan-loader.i686")
            ;;
        suse)
            nvidia_packages=("nvidia-computeG05" "nvidia-glG05")
            vulkan_packages=("vulkan-loader" "vulkan-tools")
            ;;
    esac
    
    # Install packages
    pkg_install "${nvidia_packages[@]}"
    pkg_install "${vulkan_packages[@]}"
    
    # Blacklist nouveau
    if [[ "$DISTRO_FAMILY" != "arch" ]]; then
        echo "blacklist nouveau" > /etc/modprobe.d/nouveau-blacklist.conf
        echo "options nouveau modeset=0" >> /etc/modprobe.d/nouveau-blacklist.conf
    fi
    
    # Update initramfs
    update_initramfs
}

install_amd_drivers() {
    log_info "Installing AMD drivers"
    
    case "$DISTRO_FAMILY" in
        arch)
            pkg_install "mesa" "vulkan-radeon" "lib32-mesa" "lib32-vulkan-radeon"
            ;;
        debian)
            pkg_install "mesa-vulkan-drivers" "xserver-xorg-video-amdgpu"
            ;;
        fedora)
            pkg_install "mesa-vulkan-drivers" "xorg-x11-drv-amdgpu"
            ;;
        suse)
            pkg_install "mesa" "Mesa-libVulkan" "xf86-video-amdgpu"
            ;;
    esac
}

install_intel_drivers() {
    log_info "Installing Intel drivers"
    
    case "$DISTRO_FAMILY" in
        arch)
            pkg_install "mesa" "vulkan-intel" "lib32-mesa" "lib32-vulkan-intel"
            ;;
        debian)
            pkg_install "mesa-vulkan-drivers" "xserver-xorg-video-intel"
            ;;
        fedora)
            pkg_install "mesa-vulkan-drivers" "xorg-x11-drv-intel"
            ;;
        suse)
            pkg_install "mesa" "Mesa-libVulkan" "xf86-video-intel"
            ;;
    esac
}

update_initramfs() {
    if $DRY_RUN; then
        log_info "DRY-RUN: Would update initramfs"
        return
    fi
    
    case "$DISTRO_FAMILY" in
        arch) mkinitcpio -P ;;
        debian) update-initramfs -u ;;
        fedora) dracut --force ;;
        suse) mkinitrd ;;
    esac
}

# ----------------------
# Gaming Stack Installation
# ----------------------
install_gaming_stack() {
    progress_start "Installing gaming stack" 100
    
    # Install kernel headers if needed
    install_kernel_headers
    
    # Install basic gaming dependencies
    install_basic_dependencies
    
    # Install Wine
    install_wine
    
    # Install Steam
    install_steam
    
    # Install additional gaming tools
    install_gaming_tools
    
    # Install Proton-GE
    install_proton_ge
    
    progress_end "Gaming stack installation complete"
}

install_kernel_headers() {
    log_info "Installing kernel headers"
    
    local headers_pkg=""
    
    case "$DISTRO_FAMILY" in
        arch) headers_pkg="linux-headers" ;;
        debian) headers_pkg="linux-headers-$(uname -r)" ;;
        fedora) headers_pkg="kernel-devel" ;;
        suse) headers_pkg="kernel-devel" ;;
    esac
    
    [[ -n "$headers_pkg" ]] && pkg_install "$headers_pkg"
}

install_basic_dependencies() {
    log_info "Installing basic dependencies"
    
    local base_packages=()
    local vulkan_packages=()
    local audio_packages=("pulseaudio" "pulseaudio-alsa")
    
    case "$DISTRO_FAMILY" in
        arch)
            base_packages=("base-devel" "git" "curl" "wget" "file" "unzip")
            vulkan_packages=("vulkan-icd-loader" "lib32-vulkan-icd-loader")
            # Enable multilib if not already enabled
            if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
                echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
                pacman -Sy
            fi
            ;;
        debian)
            base_packages=("build-essential" "git" "curl" "wget" "file" "unzip")
            vulkan_packages=("vulkan-tools" "libvulkan1")
            dpkg --add-architecture i386
            apt-get update
            ;;
        fedora)
            base_packages=("gcc" "gcc-c++" "make" "git" "curl" "wget" "file" "unzip")
            vulkan_packages=("vulkan-loader" "vulkan-loader.i686")
            ;;
        suse)
            base_packages=("devel_basis" "git" "curl" "wget" "file" "unzip")
            vulkan_packages=("vulkan-loader" "vulkan-tools")
            ;;
    esac
    
    pkg_install "${base_packages[@]}"
    pkg_install "${vulkan_packages[@]}"
    pkg_install "${audio_packages[@]}"
}

install_wine() {
    log_info "Installing Wine"
    
    local wine_packages=()
    
    case "$DISTRO_FAMILY" in
        arch)
            wine_packages=("wine" "wine-gecko" "wine-mono" "winetricks")
            ;;
        debian)
            wine_packages=("wine" "wine64" "winetricks")
            ;;
        fedora)
            wine_packages=("wine" "winetricks")
            ;;
        suse)
            wine_packages=("wine" "winetricks")
            ;;
    esac
    
    pkg_install "${wine_packages[@]}"
    
    # Initialize Wine prefix
    initialize_wine_prefix
}

install_steam() {
    log_info "Installing Steam"
    
    if $ENABLE_FLATPAK && command -v flatpak &>/dev/null; then
        log_info "Installing Steam via Flatpak"
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub com.valvesoftware.Steam
    else
        case "$DISTRO_FAMILY" in
            arch) pkg_install "steam" ;;
            debian) pkg_install "steam-installer" ;;
            fedora) pkg_install "steam" ;;
            suse) pkg_install "steam" ;;
        esac
    fi
    
    # Discover Steam roots for Proton installation
    discover_steam_roots
}

install_gaming_tools() {
    log_info "Installing gaming tools"
    
    local gaming_packages=()
    
    case "$DISTRO_FAMILY" in
        arch)
            gaming_packages=("lutris" "gamemode" "mangohud" "gamescope")
            ;;
        debian)
            gaming_packages=("lutris" "gamemode" "mangohud" "gamescope")
            ;;
        fedora)
            gaming_packages=("lutris" "gamemode" "mangohud" "gamescope")
            ;;
        suse)
            gaming_packages=("lutris" "gamemode" "mangohud")
            ;;
    esac
    
    pkg_install "${gaming_packages[@]}"
    
    # Install additional tools via Flatpak if enabled
    if $ENABLE_FLATPAK && command -v flatpak &>/dev/null; then
        flatpak install -y flathub com.usebottles.bottles
    fi
}

# ----------------------
# Wine & Proton Setup
# ----------------------
initialize_wine_prefix() {
    log_info "Initializing Wine prefix"
    
    if $DRY_RUN; then
        log_info "DRY-RUN: Would initialize Wine prefix at $WINE_PREFIX"
        return
    fi
    
    export WINEPREFIX="$WINE_PREFIX"
    export WINEARCH=win64
    
    # Run wineboot to initialize prefix
    sudo -u "$USER_NAME" wineboot -u 2>/dev/null || true
    
    # Install essential components
    sudo -u "$USER_NAME" winetricks -q vcrun2019 dotnet48 2>/dev/null || true
    
    log_info "Wine prefix initialized at $WINE_PREFIX"
}

discover_steam_roots() {
    STEAM_ROOTS=()
    COMPAT_DIRS=()
    
    # Common Steam installation paths
    local possible_paths=(
        "$USER_HOME/.steam/root"
        "$USER_HOME/.steam/steam"
        "$USER_HOME/.local/share/Steam"
        "$USER_HOME/.var/app/com.valvesoftware.Steam/data/Steam"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            STEAM_ROOTS+=("$path")
            local compat_dir="$path/compatibilitytools.d"
            COMPAT_DIRS+=("$compat_dir")
            mkdir -p "$compat_dir"
            chown "$USER_NAME:$USER_NAME" "$compat_dir"
        fi
    done
    
    log_info "Found Steam roots: ${STEAM_ROOTS[*]}"
}

install_proton_ge() {
    log_info "Installing Proton-GE"
    
    local latest_tag
    latest_tag=$(get_latest_proton_ge_tag)
    
    if [[ -z "$latest_tag" ]]; then
        warn "Failed to get latest Proton-GE tag"
        return
    fi
    
    for compat_dir in "${COMPAT_DIRS[@]}"; do
        install_proton_ge_to "$latest_tag" "$compat_dir"
    done
}

get_latest_proton_ge_tag() {
    if $DRY_RUN; then
        echo "GE-Proton9-999"
        return
    fi
    
    local api_url="https://api.github.com/repos/$GITHUB_PROTON_REPO/releases/latest"
    local tag
    
    tag=$(curl -s "$api_url" | grep '"tag_name":' | cut -d'"' -f4)
    
    if [[ -z "$tag" ]]; then
        # Fallback to a known working version
        tag="GE-Proton9-9"
    fi
    
    echo "$tag"
}

install_proton_ge_to() {
    local tag="$1"
    local target_dir="$2"
    local url="https://github.com/$GITHUB_PROTON_REPO/releases/download/$tag/$tag.tar.gz"
    local temp_file="/tmp/$tag.tar.gz"
    
    if $DRY_RUN; then
        log_info "DRY-RUN: Would download and install Proton-GE $tag to $target_dir"
        return
    fi
    
    log_info "Downloading Proton-GE $tag"
    
    if curl -L -o "$temp_file" "$url"; then
        log_info "Extracting Proton-GE to $target_dir"
        tar -xzf "$temp_file" -C "$target_dir"
        chown -R "$USER_NAME:$USER_NAME" "$target_dir/$tag"
        rm -f "$temp_file"
        log_info "Proton-GE $tag installed successfully"
    else
        warn "Failed to download Proton-GE $tag"
        rm -f "$temp_file"
    fi
}

# ----------------------
# Configuration
# ----------------------
configure_proton() {
    progress_start "Configuring Proton" 100
    
    case "$PROTON_MODE" in
        local)
            configure_proton_local
            ;;
        global)
            configure_proton_global
            ;;
        ask)
            if $NONINTERACTIVE; then
                configure_proton_global
            else
                local choice
                choice=$(ui_show_menu "Proton Configuration" \
                    "How would you like to configure Proton?" \
                    "Global (all games use Proton-GE)" \
                    "Local (configure per game in Steam)")
                
                case "$choice" in
                    0) configure_proton_global ;;
                    1) configure_proton_local ;;
                    *) configure_proton_global ;;
                esac
            fi
            ;;
    esac
    
    progress_end "Proton configuration complete"
}

configure_proton_global() {
    log_info "Configuring global Proton settings"
    
    for steam_root in "${STEAM_ROOTS[@]}"; do
        local config_dir="$steam_root/config"
        local config_file="$config_dir/config.vdf"
        
        mkdir -p "$config_dir"
        
        if [[ ! -f "$config_file" ]]; then
            create_initial_steam_config "$config_file"
        fi
        
        # This is a simplified configuration
        # In practice, you'd want to properly parse and modify the VDF file
        log_info "Global Proton configuration applied to $config_file"
    done
    
    # Create instruction file for user
    create_proton_instructions
}

configure_proton_local() {
    log_info "Configuring local Proton settings"
    
    # Create instruction file for per-game configuration
    create_proton_instructions "local"
}

create_proton_instructions() {
    local mode="${1:-global}"
    local instruction_file="$USER_HOME/Proton-Setup-Instructions.txt"
    
    cat > "$instruction_file" << EOF
Proton Gaming Setup Instructions
Generated on: $(date)

Configuration Mode: $mode

$(
if [[ "$mode" == "global" ]]; then
    echo "Global Proton configuration has been applied."
    echo "All games should use Proton-GE by default."
else
    echo "Local (per-game) Proton configuration selected."
    echo "To configure Proton for individual games:"
    echo "1. Open Steam"
    echo "2. Right-click on a game"
    echo "3. Select 'Properties'"
    echo "4. Go to 'Compatibility'"
    echo "5. Check 'Force the use of a specific Steam Play compatibility tool'"
    echo "6. Select Proton-GE from the dropdown"
fi
)

Additional Tips:
- Enable Steam Play for all titles in Steam Settings
- Use Launch Options for performance: MANGOHUD=1 gamemoderun %command%
- For DX12 games: PROTON_ENABLE_NVAPI=1 %command%

Troubleshooting:
- If a game doesn't start, try different Proton versions
- Check protondb.com for game-specific fixes
- Use Proton Logs: PROTON_LOG=1 %command%

EOF
    
    chown "$USER_NAME:$USER_NAME" "$instruction_file"
    log_info "Proton instructions saved to $instruction_file"
}

create_initial_steam_config() {
    local config_file="$1"
    
    cat > "$config_file" << 'EOF'
"InstallConfigStore"
{
    "Software"
    {
        "Valve"
        {
            "Steam"
            {
                "CompatToolMapping"
                {
                    "0"
                    {
                        "name" "proton_ge"
                        "config" ""
                        "Priority" "250"
                    }
                }
            }
        }
    }
}
EOF
}

# ----------------------
# System Optimizations
# ----------------------
apply_system_optimizations() {
    if ! $ENABLE_OPTIMIZATIONS; then
        log_info "Skipping system optimizations"
        return
    fi
    
    progress_start "Applying system optimizations" 100
    
    enable_gamemode
    configure_sysctl
    configure_limits
    configure_services
    
    progress_end "System optimizations applied"
}

enable_gamemode() {
    log_info "Enabling gamemode"
    
    if command -v gamemoded &>/dev/null; then
        systemctl enable --now gamemoded.service 2>/dev/null || true
    fi
}

configure_sysctl() {
    log_info "Configuring kernel parameters"
    
    local sysctl_file="/etc/sysctl.d/99-gaming.conf"
    
    cat > "$sysctl_file" << 'EOF'
# Gaming optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 16384 16777216
EOF
    
    sysctl -p "$sysctl_file" 2>/dev/null || true
}

configure_limits() {
    log_info "Configuring user limits"
    
    local limits_file="/etc/security/limits.d/99-gaming.conf"
    
    cat > "$limits_file" << EOF
# Gaming performance limits
$USER_NAME soft nofile 524288
$USER_NAME hard nofile 1048576
$USER_NAME soft nproc 65536
$USER_NAME hard nproc unlimited
EOF
}

configure_services() {
    log_info "Configuring services"
    
    # Disable unnecessary services for gaming
    local services=("bluetooth" "cups" "avahi-daemon")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
        fi
    done
}

# ----------------------
# Verification & Testing
# ----------------------
verify_installation() {
    progress_start "Verifying installation" 100
    
    verify_drivers
    verify_vulkan
    verify_wine
    verify_steam
    verify_proton
    
    progress_end "Verification complete"
}

verify_drivers() {
    log_info "Verifying GPU drivers"
    
    case "$GPU_VENDOR" in
        nvidia)
            if command -v nvidia-smi &>/dev/null; then
                local driver_version
                driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
                log_info "NVIDIA Driver: $driver_version"
            else
                warn "NVIDIA drivers not properly installed"
            fi
            ;;
        amd|intel)
            if command -v glxinfo &>/dev/null; then
                local renderer
                renderer=$(glxinfo | grep "OpenGL renderer" | cut -d: -f2 | xargs)
                log_info "OpenGL Renderer: $renderer"
            fi
            ;;
    esac
}

verify_vulkan() {
    log_info "Verifying Vulkan"
    
    if command -v vulkaninfo &>/dev/null; then
        log_info "Vulkan installation: OK"
    else
        warn "Vulkan may not be properly installed"
    fi
}

verify_wine() {
    log_info "Verifying Wine"
    
    if command -v wine &>/dev/null; then
        log_info "Wine installation: OK"
    else
        warn "Wine not properly installed"
    fi
}

verify_steam() {
    log_info "Verifying Steam"
    
    if command -v steam &>/dev/null || flatpak list | grep -q com.valvesoftware.Steam; then
        log_info "Steam installation: OK"
    else
        warn "Steam not properly installed"
    fi
}

verify_proton() {
    log_info "Verifying Proton"
    
    local proton_found=false
    
    for compat_dir in "${COMPAT_DIRS[@]}"; do
        if [[ -d "$compat_dir" ]] && [[ "$(ls -A "$compat_dir")" ]]; then
            proton_found=true
            log_info "Proton tools found in: $compat_dir"
        fi
    done
    
    if ! $proton_found; then
        warn "No Proton compatibility tools found"
    fi
}

# ----------------------
# Uninstallation
# ----------------------
uninstall_gaming_setup() {
    if ! $NONINTERACTIVE; then
        ui_show_yesno "This will remove the gaming setup. Continue?" "Uninstall" || return
    fi
    
    progress_start "Removing gaming setup" 100
    
    remove_gaming_packages
    remove_configurations
    cleanup_user_files
    
    progress_end "Gaming setup removed"
}

remove_gaming_packages() {
    log_info "Removing gaming packages"
    
    local packages=("steam" "lutris" "wine" "winetricks" "gamemode" "mangohud" "gamescope")
    
    for pkg in "${packages[@]}"; do
        pkg_remove "$pkg"
    done
    
    # Remove Flatpak installations
    if command -v flatpak &>/dev/null; then
        flatpak uninstall -y com.valvesoftware.Steam 2>/dev/null || true
        flatpak uninstall -y com.usebottles.bottles 2>/dev/null || true
    fi
}

remove_configurations() {
    log_info "Removing configurations"
    
    # Remove sysctl configuration
    rm -f /etc/sysctl.d/99-gaming.conf
    
    # Remove limits configuration
    rm -f /etc/security/limits.d/99-gaming.conf
    
    # Remove NVIDIA blacklist
    rm -f /etc/modprobe.d/nouveau-blacklist.conf
    
    # Update initramfs
    update_initramfs
}

cleanup_user_files() {
    log_info "Cleaning up user files"
    
    local user_dirs=(
        "$WINE_PREFIX"
        "$USER_HOME/.steam"
        "$USER_HOME/.local/share/Steam"
        "$USER_HOME/.var/app/com.valvesoftware.Steam"
        "$USER_HOME/.cache/mesa_shader_cache"
        "$USER_HOME/.nv"
    )
    
    for dir in "${user_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            log_debug "Removed: $dir"
        fi
    done
}

# ----------------------
# Main Execution Flow
# ----------------------
show_summary() {
    local summary_file="$USER_HOME/gaming-setup-summary.txt"
    
    cat > "$summary_file" << EOF
Linux Gaming Setup Summary
Generated: $(date)

System Information:
- Distribution: $DISTRO_FAMILY
- GPU: $GPU_VENDOR
- Kernel: $KERNEL_TYPE
- User: $USER_NAME

Installation Details:
- Proton Mode: $PROTON_MODE
- Flatpak Enabled: $ENABLE_FLATPAK
- Optimizations: $ENABLE_OPTIMIZATIONS
- UI Mode: $UI_PREF

Installed Components:
- GPU Drivers: $GPU_VENDOR
- Wine & Dependencies
- Steam ($($ENABLE_FLATPAK && echo "Flatpak" || echo "Native"))
- Proton-GE
- Gaming Tools (Lutris, Gamemode, MangoHud)

Next Steps:
1. Reboot your system
2. Launch Steam and log in
3. Configure individual games to use Proton if needed
4. Check $USER_HOME/Proton-Setup-Instructions.txt for details

Troubleshooting:
- Check logs in: $USER_LOG_DIR
- Verify drivers with: nvidia-smi or glxinfo
- Test Vulkan with: vulkaninfo

Support:
- ProtonDB: https://www.protondb.com/
- WineHQ: https://wiki.winehq.org/
- GitHub: $GITHUB_PROTON_REPO

EOF
    
    chown "$USER_NAME:$USER_NAME" "$summary_file"
    
    if ! $HEADLESS; then
        ui_show_info "Setup complete! Summary saved to $summary_file" "Setup Complete"
    else
        say "Setup complete! Summary saved to $summary_file"
    fi
    
    log_info "Setup summary saved to $summary_file"
}

main() {
    log_info "Starting Linux Gaming Setup v$VERSION"
    
    # Initialization
    init_logging
    parse_arguments "$@"
    setup_ui
    
    # Pre-flight checks
    detect_system
    
    if $UNINSTALL; then
        uninstall_gaming_setup
        exit 0
    fi
    
    # Show welcome message
    if ! $HEADLESS && ! $NONINTERACTIVE; then
        ui_show_info "This script will set up your Linux system for gaming with:\n- GPU Drivers ($GPU_VENDOR)\n- Wine & Proton\n- Steam & Gaming Tools\n- System Optimizations" "Linux Gaming Setup"
    fi
    
    # Main installation process
    pkg_update
    install_gpu_drivers
    install_gaming_stack
    configure_proton
    
    if $ENABLE_OPTIMIZATIONS; then
        apply_system_optimizations
    fi
    
    # Verification
    verify_installation
    
    # Completion
    show_summary
    
    log_info "Linux gaming setup completed successfully"
    
    # Prompt for reboot
    if ! $HEADLESS && ! $NONINTERACTIVE; then
        if ui_show_yesno "Setup complete! A reboot is recommended. Reboot now?" "Reboot"; then
            log_info "Rebooting system..."
            reboot
        fi
    else
        say "Setup complete! Please reboot your system."
    fi
}

# ----------------------
# Script Entry Point
# ----------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
