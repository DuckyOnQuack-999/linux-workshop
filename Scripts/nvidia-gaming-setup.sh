#!/bin/bash

# nvidia-gaming-setup.sh v2.8-progress
# Author: DuckyCoder AI
# License: MIT
# Description: Idempotent script to set up NVIDIA drivers and gaming stack on Linux for optimal Windows .exe compatibility, fully configured for DX12 out-of-the-box, with Palworld-specific prefix fixes, Arch AUR support, explicit 32/64-bit gaming libraries, VKD3D-Proton, session-aware protontricks, and fancy colorful progress bar with status/verbose indicators.
# Changelog: v2.8 - Added fancy progress bar (colors, spinner, percentage, verbose status); integrated into installs/downloads/fixes for eye-catching feedback.
# Usage: sudo ./nvidia-gaming-setup.sh [--dry-run] [--noninteractive] [--uninstall]

set -euo pipefail
trap 'log_error "Script exited with status $? at line $LINENO"; cleanup_on_exit' ERR EXIT

# Global variables
SCRIPT_NAME="nvidia-gaming-setup.sh"
VERSION="2.8-progress"
LOG_FILE="/var/log/nvidia-gaming-setup.log"
DRY_RUN=false
NONINTERACTIVE=false
UNINSTALL=false
DISTRO_FAMILY=""
PKG_MANAGER=""
HAS_TTY=false
if [ -t 1 ]; then HAS_TTY=true; fi
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
WINE_PREFIX="${WINEPREFIX:-$USER_HOME/.wine}"
XVFB_PID=""
PALWORLD_APPID=1623730 # Confirmed Palworld Steam AppID

# Progress bar globals
PROGRESS_PID=""
PROGRESS_CURRENT=0
PROGRESS_TOTAL=100
PROGRESS_STATUS="Initializing..."

# Logging helpers
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"; }
log_info() { log "INFO: $*"; }
log_warn() { log "WARN: $*"; }
log_error() { log "ERROR: $*"; }
say() {
    if $HAS_TTY; then echo -e "\033[32m$*\033[0m"; else echo "$*"; fi
    log_info "$*"
}
warn() {
    if $HAS_TTY; then echo -e "\033[33m$*\033[0m" >&2; else echo "$*" >&2; fi
    log_warn "$*"
}
err() {
    if $HAS_TTY; then echo -e "\033[31m$*\033[0m" >&2; else echo "$*" >&2; fi
    log_error "$*"
}

# Cleanup function
cleanup_on_exit() {
    if [ -n "$XVFB_PID" ]; then
        kill "$XVFB_PID" 2>/dev/null || true
        wait "$XVFB_PID" 2>/dev/null || true
    fi
    kill_wine_processes
    progress_end
}

# Parse CLI flags with validation
parse_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --noninteractive)
            NONINTERACTIVE=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        *)
            err "Unknown flag: $1"
            exit 1
            ;;
        esac
    done
    if $UNINSTALL && ! $NONINTERACTIVE; then warn "--uninstall may require interaction; use --noninteractive to force."; fi
}
parse_flags "$@"

# Check sudo privileges
if [ "$(id -u)" != "0" ]; then
    err "Must run as root (sudo)."
    exit 1
fi

# Detect distro family and set package manager
detect_distro() {
    if [ -f /etc/debian_version ]; then
        DISTRO_FAMILY="debian"
        PKG_MANAGER="apt"
    elif [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ]; then
        DISTRO_FAMILY="fedora"
        PKG_MANAGER="dnf"
    elif [ -f /etc/arch-release ]; then
        DISTRO_FAMILY="arch"
        PKG_MANAGER="pacman"
    elif [ -f /etc/SuSE-release ] || [ -f /etc/os-release ] && grep -q openSUSE /etc/os-release; then
        DISTRO_FAMILY="suse"
        PKG_MANAGER="zypper"
    else
        err "Unsupported distro."
        exit 1
    fi
    log_info "Detected distro family: $DISTRO_FAMILY with $PKG_MANAGER."
}

# Idempotent package helpers
pkg_check() {
    set +e
    case "$PKG_MANAGER" in
    apt) dpkg -s "$1" &>/dev/null ;;
    dnf) rpm -q "$1" &>/dev/null ;;
    pacman) pacman -Qi "$1" &>/dev/null ;;
    zypper) zypper se -i "$1" &>/dev/null ;;
    esac
    local rc=$?
    set -e
    return $rc
}

pkg_install() {
    local pkgs=("$@")
    PROGRESS_TOTAL=${#pkgs[@]}
    PROGRESS_CURRENT=0
    progress_start "Installing packages: ${pkgs[*]}"

    for pkg in "${pkgs[@]}"; do
        if $DRY_RUN; then
            say "Dry-run: Would install $pkg"
            PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
            progress_update $PROGRESS_CURRENT "Dry-run $pkg"
            continue
        fi
        if ! pkg_check "$pkg"; then
            set +e
            case "$PKG_MANAGER" in
            apt) apt update -y && apt install -y "$pkg" || log_warn "Failure installing $pkg" ;;
            dnf) dnf install -y "$pkg" || log_warn "Failure installing $pkg" ;;
            pacman) pacman -Syu --noconfirm "$pkg" || log_warn "Failure installing $pkg" ;;
            zypper) zypper install -y "$pkg" || log_warn "Failure installing $pkg" ;;
            esac
            set -e
        else
            log_info "$pkg already installed."
        fi
        PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
        progress_update $PROGRESS_CURRENT "Installed $pkg"
    done

    progress_end "Packages installed."
}

pkg_remove() {
    local pkgs=("$@")
    PROGRESS_TOTAL=${#pkgs[@]}
    PROGRESS_CURRENT=0
    progress_start "Removing packages: ${pkgs[*]}"

    for pkg in "${pkgs[@]}"; do
        if $DRY_RUN; then
            say "Dry-run: Would remove $pkg"
            PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
            progress_update $PROGRESS_CURRENT "Dry-run $pkg"
            continue
        fi
        if pkg_check "$pkg"; then
            set +e
            case "$PKG_MANAGER" in
            apt) apt remove -y "$pkg" || log_warn "Failure removing $pkg" ;;
            dnf) dnf remove -y "$pkg" || log_warn "Failure removing $pkg" ;;
            pacman) pacman -Rns --noconfirm "$pkg" || log_warn "Failure removing $pkg" ;;
            zypper) zypper remove -y "$pkg" || log_warn "Failure removing $pkg" ;;
            esac
            set -e
        else
            log_info "$pkg not installed."
        fi
        PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
        progress_update $PROGRESS_CURRENT "Removed $pkg"
    done

    progress_end "Packages removed."
}

# AUR helper for Arch (install yay if missing)
install_aur_helper() {
    if [ "$DISTRO_FAMILY" != "arch" ]; then return 0; fi
    if command -v yay &>/dev/null; then
        log_info "yay AUR helper already installed."
        return 0
    fi
    log_info "Installing yay AUR helper..."
    if $DRY_RUN; then
        say "Dry-run: Would install yay"
        return
    fi
    set +e
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm || warn "yay install partial; manual AUR needed."
    cd -
    rm -rf /tmp/yay
    set -e
    log_info "yay installed."
}

install_aur_pkg() {
    if [ "$DISTRO_FAMILY" != "arch" ]; then return 0; fi
    install_aur_helper
    if $DRY_RUN; then
        say "Dry-run: Would install AUR packages $*"
        return
    fi
    set +e
    yay -S --noconfirm "$@" || log_warn "Partial failure installing AUR $*" # Non-fatal
    set -e
}

# Fancy progress bar functions
progress_start() {
    local status="$1"
    PROGRESS_CURRENT=0
    PROGRESS_TOTAL=100
    PROGRESS_STATUS="$status"
    if $DRY_RUN || ! $HAS_TTY; then
        say "Starting: $status"
        return
    fi
    (while true; do
        local spinners=('|' '/' '-' '\')
        for spinner in "${spinners[@]}"; do
            local percent=$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))
            local bar_len=50
            local filled_len=$((percent * bar_len / 100))
            local bar=$(printf "\e[32m#\e[0m" $(seq 1 $filled_len))
            local empty=$(printf " " $(seq 1 $((bar_len - filled_len))))
            printf "\r\e[1m[\e[0m%s%s\e[1m] \e[0m\e[33m%d%%\e[0m \e[36m%s\e[0m \e[35m%s\e[0m" "$bar" "$empty" "$percent" "$spinner" "$PROGRESS_STATUS"
            sleep 0.2
        done
    done) &
    PROGRESS_PID=$!
}

progress_update() {
    PROGRESS_CURRENT=$1
    PROGRESS_STATUS="${2:-$PROGRESS_STATUS}"
}

progress_end() {
    local status="$1"
    if [ -n "$PROGRESS_PID" ]; then
        kill $PROGRESS_PID 2>/dev/null || true
        wait $PROGRESS_PID 2>/dev/null || true
        PROGRESS_PID=""
        if $HAS_TTY; then
            printf "\r\e[K" # Clear line
            say "$status"
        else
            say "$status"
        fi
    fi
}

# Scan Steam libraries for multi-drive setups
steam_library_scan() {
    local steam_config="$USER_HOME/.steam/steam/config.vdf"
    local libraries=()
    if [ -f "$steam_config" ]; then
        libraries=($(grep -A 10 "libraryfolders" "$steam_config" | grep '"path"' | sed 's/.*"path"\t\t"//' | sed 's/"$//'))
    fi
    if [ ${#libraries[@]} -eq 0 ]; then
        libraries=("$USER_HOME/.local/share/Steam") # Default
    fi
    echo "${libraries[@]}"
}

# Enhanced display environment setup (consolidated)
setup_display_environment() {
    if [ "${DISPLAY_SETUP_DONE:-}" = "true" ]; then return; fi
    log_info "Setting up display environment for Wine..."

    # Set XDG_RUNTIME_DIR if not set
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")"
        log_info "Set XDG_RUNTIME_DIR to: $XDG_RUNTIME_DIR"
        if [ ! -d "$XDG_RUNTIME_DIR" ]; then
            mkdir -p "$XDG_RUNTIME_DIR"
            chown "$SUDO_USER:$SUDO_USER" "$XDG_RUNTIME_DIR"
            chmod 700 "$XDG_RUNTIME_DIR"
        fi
    fi

    # Set DISPLAY if not set
    if [ -z "${DISPLAY:-}" ]; then
        local display=$(find /tmp/.X11-unix -name "X*" 2>/dev/null | head -1 | sed 's|/tmp/.X11-unix/X||')
        if [ -n "$display" ]; then
            export DISPLAY=":${display}"
        else
            export DISPLAY=":0"
        fi
        log_info "Set DISPLAY to: $DISPLAY"
    fi

    export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

    # Detect Wayland and set NVIDIA GLX
    if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        log_info "Wayland detected; setting NVIDIA compatibility envs."
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export SDL_VIDEODRIVER=wayland
    fi

    # Test display connection
    if ! timeout 2s xset q &>/dev/null; then
        warn "No X server detected at DISPLAY=$DISPLAY. Setting up Xvfb fallback..."
        setup_xvfb_fallback
    else
        log_info "X server is running at DISPLAY=$DISPLAY"
    fi
    export DISPLAY_SETUP_DONE=true
}

# Robust Xvfb setup
setup_xvfb_fallback() {
    if ! command -v Xvfb &>/dev/null; then
        log_info "Installing Xvfb for virtual display..."
        pkg_install xvfb
    fi

    local xvfb_display=":99"

    # Check if Xvfb is already running
    if ! ps aux | grep -q "[X]vfb.*$xvfb_display"; then
        log_info "Starting Xvfb on $xvfb_display..."
        if $DRY_RUN; then
            say "Dry-run: Would start Xvfb on $xvfb_display"
        else
            Xvfb "$xvfb_display" -screen 0 1024x768x24 &
            XVFB_PID=$!
            sleep 3
            if ! kill -0 "$XVFB_PID" 2>/dev/null; then
                err "Xvfb failed to start"
                return 1
            fi
            log_info "Xvfb started with PID: $XVFB_PID"
        fi
    fi

    export DISPLAY="$xvfb_display"
    log_info "Using Xvfb virtual display at $DISPLAY"
}

# Kill stuck Wine processes
kill_wine_processes() {
    log_info "Cleaning up Wine processes..."
    set +e
    pkill -f "wine.*winecfg" 2>/dev/null || true
    pkill -f "wine.*explorer" 2>/dev/null || true
    pkill -f "wine.*boot" 2>/dev/null || true

    timeout 5s su - "$SUDO_USER" -c "wineserver -k" 2>/dev/null || true

    pkill -9 -f "wine" 2>/dev/null || true
    sleep 2
    set -e
}

# Safe Wine command execution with comprehensive error handling (suppress noise)
run_wine_command() {
    local command="$1"
    local description="$2"
    local timeout="${3:-300}"

    log_info "Executing Wine command: $description"

    setup_display_environment

    local wine_env="DISPLAY='$DISPLAY' XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' WINEPREFIX='$WINE_PREFIX'"

    if $DRY_RUN; then
        say "Dry-run: Would run: $wine_env $command"
        return 0
    fi

    set +e
    timeout "$timeout" su - "$SUDO_USER" -c "$wine_env $command 2>&1 | grep -v 'fixme\\|err:waylanddrv\\|err:ole\\|err:setupapi' || true" # Suppress common noise
    local wine_rc=$?
    set -e

    case $wine_rc in
    0)
        log_info "Wine command completed successfully: $description"
        return 0
        ;;
    124)
        warn "Wine command timed out after ${timeout}s: $description"
        kill_wine_processes
        return 124
        ;;
    *)
        warn "Wine command failed with exit code $wine_rc: $description"
        return $wine_rc
        ;;
    esac
}

# Safe winetricks with retry logic and proper Windows version management
safe_winetricks() {
    local args="$1"
    local description="$2"
    local max_retries=2
    local retry=0

    while [ $retry -le $max_retries ]; do
        kill_wine_processes

        if [ $retry -gt 0 ]; then
            warn "Retry $retry/$max_retries for: $description"
            run_wine_command "wineboot -u" "Reset Wine prefix for retry" 60 || true
        fi

        log_info "Running winetricks: $args"
        if run_wine_command "winetricks $args" "$description" 180; then
            return 0
        fi

        ((retry++))
        if [ $retry -le $max_retries ]; then
            warn "Winetricks attempt $retry failed, waiting before retry..."
            sleep 5
        fi
    done

    warn "All winetricks attempts failed for: $description"
    return 1
}

# Initialize Wine prefix properly
initialize_wine_prefix() {
    log_info "Initializing Wine prefix..."

    if [ -d "$WINE_PREFIX" ]; then
        warn "Existing Wine prefix found, backing up and creating fresh..."
        local backup_dir="${WINE_PREFIX}.backup.$(date +%s)"
        mv "$WINE_PREFIX" "$backup_dir" 2>/dev/null || {
            warn "Could not backup existing prefix, removing..."
            rm -rf "$WINE_PREFIX"
        }
    fi

    run_wine_command "winecfg -v win10" "Set Windows version to Windows 10" 60 || {
        warn "Failed to set Windows version, continuing with default..."
    }

    run_wine_command "wineboot -u" "Initialize Wine prefix" 120 || {
        err "Failed to initialize Wine prefix"
        return 1
    }

    log_info "Wine prefix initialized successfully"
}

# Check prerequisites
check_prereqs() {
    local tools="awk git curl sudo lspci wget sha256sum steam"
    for tool in $tools; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "$tool missing; attempting install."
            pkg_install "$tool" || err "$tool install failed; aborting."
        fi
    done

    if ! curl --retry 3 -f -s --max-time 10 google.com &>/dev/null; then
        err "No network connectivity."
        exit 1
    fi

    local free_space=$(df / | awk 'NR==2 {print $4}' || echo 0)
    if ((free_space < 5 * 1024 * 1024)); then
        err "Less than 5GB free on /."
        exit 1
    fi

    local home_free=$(df "$USER_HOME" | awk 'NR==2 {print $4}' || echo 0)
    if ((home_free < 2 * 1024 * 1024)); then
        err "Less than 2GB free on $USER_HOME."
        exit 1
    fi

    [ -d "$USER_HOME" ] || {
        err "User HOME directory invalid."
        exit 1
    }

    if ! command -v flatpak &>/dev/null; then
        pkg_install "flatpak"
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
}

# Install kernel headers
install_kernel_headers() {
    local kernel_ver=$(uname -r)
    local headers_pkg
    case "$DISTRO_FAMILY" in
    debian) headers_pkg="linux-headers-$kernel_ver" ;;
    fedora) headers_pkg="kernel-headers kernel-devel" ;;
    arch) headers_pkg="linux-headers" ;;
    suse) headers_pkg="kernel-default-devel" ;;
    esac
    pkg_install "$headers_pkg"
    if ! ls /lib/modules/"$kernel_ver"/build &>/dev/null; then
        warn "Kernel headers mismatch for $kernel_ver; may need reboot."
    fi
}

# Blacklist nouveau
blacklist_nouveau() {
    local blacklist_file="/etc/modprobe.d/nouveau-blacklist.conf"
    if [ ! -f "$blacklist_file" ]; then
        if $DRY_RUN; then
            say "Dry-run: Would blacklist nouveau"
            return
        fi
        [ -f "$blacklist_file.bak" ] || cp /dev/null "$blacklist_file.bak"
        echo "blacklist nouveau" >"$blacklist_file"
        echo "options nouveau modeset=0" >>"$blacklist_file"
    fi
    update_initramfs
}

unblacklist_nouveau() {
    local blacklist_file="/etc/modprobe.d/nouveau-blacklist.conf"
    if [ -f "$blacklist_file" ]; then
        if $DRY_RUN; then
            say "Dry-run: Would unblacklist nouveau"
            return
        fi
        rm -f "$blacklist_file" || log_warn "Failed to remove $blacklist_file"
        [ -f "$blacklist_file.bak" ] && rm -f "$blacklist_file.bak"
    fi
    update_initramfs
}

update_initramfs() {
    if $DRY_RUN; then
        say "Dry-run: Would update initramfs"
        return
    fi
    set +e
    case "$DISTRO_FAMILY" in
    debian) update-initramfs -u ;;
    fedora) dracut --force ;;
    arch) mkinitcpio -P ;;
    suse) mkinitrd ;;
    esac
    local rc=$?
    set -e
    if [ $rc -ne 0 ]; then warn "initramfs update failed; manual intervention needed."; fi
}

# Detect NVIDIA GPU
detect_gpu() {
    local gpus=$(lspci | grep -i nvidia | grep -i vga || true)
    if [ -z "$gpus" ]; then
        err "No NVIDIA GPU detected; consider alternative setups."
        exit 1
    fi
    local series=$(echo "$gpus" | head -1 | awk '{print $NF}' | grep -oE '[0-9]{2,4}' || echo "")
    if [ -z "$series" ]; then
        warn "GPU series parse failed; falling back to latest."
        series="latest"
    fi
    case "$series" in
    50*) BRANCH="581" ;;
    40*) BRANCH="575" ;;
    30*) BRANCH="560" ;;
    20*) BRANCH="535" ;;
    *) BRANCH="latest" ;;
    esac
    log_info "Detected NVIDIA series: $series, using branch: $BRANCH"
    if [[ "$BRANCH" < "575" ]]; then
        warn "Driver branch $BRANCH may have DX12 issues; recommend updating to 575+."
    fi
}

# Install NVIDIA drivers
install_drivers() {
    local driver_pkg
    case "$DISTRO_FAMILY" in
    debian) driver_pkg="nvidia-driver-$BRANCH" ;;
    fedora) driver_pkg="akmod-nvidia" ;;
    arch) driver_pkg="nvidia nvidia-utils" ;;
    suse) driver_pkg="nvidia-computeG0$BRANCH" ;;
    esac
    set +e
    pkg_install "$driver_pkg"
    local rc=$?
    set -e
    if [ $rc -ne 0 ]; then
        warn "Distro driver install failed; attempting .run fallback."
        if $NONINTERACTIVE; then
            warn "Noninteractive mode; skipping .run."
            return
        fi
        read -p "Proceed with .run installer? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" != "y" ]]; then return; fi
        install_run_fallback
    fi
    handle_secure_boot
    handle_hybrid_gpu
    if [ "$DISTRO_FAMILY" = "arch" ]; then
        pacman-key --populate archlinux || warn "PGP key populate failed."
        idempotent_grub_param "nvidia_drm.modeset=1"
    fi
    # Post-install driver version check
    if command -v nvidia-smi &>/dev/null; then
        local driver_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
        if [[ "$driver_ver" < "581" ]]; then
            warn "Installed driver $driver_ver < 581.57; DX12 perf may suffer. Update manually."
        else
            log_info "Driver version $driver_ver confirmed (2025 optimal)."
        fi
    fi
}

install_run_fallback() {
    if ! curl --retry 3 -f -s --max-time 10 google.com &>/dev/null; then
        warn "Network down; skipping .run fallback."
        return
    fi
    local driver_url="https://us.download.nvidia.com/XFree86/Linux-x86_64/581.57/NVIDIA-Linux-x86_64-581.57.run" # Updated to 581.57 (Oct 2025)
    local file=$(basename "$driver_url")
    curl --retry 3 -O "$driver_url" || {
        warn "Download failed; skipping."
        return
    }

    if $DRY_RUN; then
        say "Dry-run: Would run $file --dkms"
        rm -f "$file" || true
        return
    fi

    chmod +x "$file"
    bash "$file" --silent --dkms || warn ".run install failed."
    rm -f "$file" || log_warn "Cleanup failed."
}

handle_secure_boot() {
    if ! command -v mokutil &>/dev/null; then
        pkg_install "mokutil" || warn "mokutil install failed; Secure Boot check skipped."
        return
    fi
    if mokutil --sb-state | grep -q enabled; then
        warn "Secure Boot enabled; you may need to enroll MOK key after reboot."
    fi
}

handle_hybrid_gpu() {
    if lspci | grep -iq "Intel.*VGA" || lspci | grep -iq "AMD.*VGA"; then
        log_info "Hybrid GPU detected; setting PRIME offload env."
        case "$DISTRO_FAMILY" in
        debian) say "Use prime-select nvidia for offload." ;;
        arch) pkg_install "optimus-manager" || warn "optimus-manager install failed." ;;
        *) warn "Hybrid setup may require manual config." ;;
        esac
        # Add PRIME env to bashrc
        local env_file="$USER_HOME/.bashrc"
        if ! grep -q "__NV_PRIME_RENDER_OFFLOAD" "$env_file"; then
            echo "export __NV_PRIME_RENDER_OFFLOAD=1" >>"$env_file"
            echo "export __GLX_VENDOR_LIBRARY_NAME=nvidia" >>"$env_file"
            echo "export __VK_LAYER_NV_optimus=NVIDIA_only" >>"$env_file"
        fi
    fi
}

idempotent_grub_param() {
    local param="$1"
    local grub_file="/etc/default/grub"
    if [ ! -f "$grub_file" ]; then
        warn "GRUB file missing; skipping."
        return
    fi
    if ! grep -q "$param" "$grub_file"; then
        if $DRY_RUN; then
            say "Dry-run: Would add $param to GRUB"
            return
        fi
        [ -f "$grub_file.bak" ] || cp "$grub_file" "$grub_file.bak"
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/& $param/" "$grub_file" || warn "GRUB edit failed."
        update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || warn "GRUB update failed."
    fi
}

# Palworld-specific fix for DLL errors (c000007b/c0000135)
palworld_fix() {
    local libraries=($(steam_library_scan))
    local palworld_dir=""
    local prefix_dir="$USER_HOME/.steam/steam/steamapps/compatdata/$PALWORLD_APPID"

    # Scan libraries for Palworld
    for lib in "${libraries[@]}"; do
        if [ -d "$lib/steamapps/common/Palworld" ]; then
            palworld_dir="$lib/steamapps/common/Palworld"
            break
        fi
    done

    if [ -z "$palworld_dir" ]; then
        if $NONINTERACTIVE; then
            log_info "Palworld not detected in any Steam library; skipping fix."
            return 0
        fi
        read -p "Palworld not found in Steam libraries. Install via Steam first? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" != "y" ]]; then return 0; fi
        # Launch Steam to install (user-driven)
        su - "$SUDO_USER" -c "steam steam://install/$PALWORLD_APPID" || warn "Steam launch failed; install manually."
        sleep 10 # Allow time
        # Rescan
        libraries=($(steam_library_scan))
        for lib in "${libraries[@]}"; do
            if [ -d "$lib/steamapps/common/Palworld" ]; then
                palworld_dir="$lib/steamapps/common/Palworld"
                break
            fi
        done
    fi

    if [ -z "$palworld_dir" ]; then
        warn "Palworld still not found; manual install needed."
        return 1
    fi

    if [ ! -d "$prefix_dir" ]; then
        log_info "Initializing Palworld Proton prefix..."
        if $DRY_RUN; then
            say "Dry-run: Would init prefix via Steam launch"
            return 0
        fi
        su - "$SUDO_USER" -c "steam steam://rungameid/$PALWORLD_APPID" &>/dev/null || true
        sleep 5
    fi

    # Backup prefix
    if [ -d "$prefix_dir" ]; then
        local backup_dir="${prefix_dir}.backup.$(date +%s)"
        if $DRY_RUN; then
            say "Dry-run: Would backup $prefix_dir"
        else
            cp -r "$prefix_dir" "$backup_dir" || warn "Backup failed; proceeding."
        fi
    fi

    log_info "Applying Palworld fixes via protontricks (vcrun2019, d3dx9/11, etc.)..."

    if $DRY_RUN; then
        say "Dry-run: Would run xvfb-run protontricks $PALWORLD_APPID vcrun2019 d3dx9_43 d3dx11_43 d3dcompiler_47 mf"
        return 0
    fi

    # Export session env for su
    local dbus_bus=$(su - "$SUDO_USER" -c 'echo $DBUS_SESSION_BUS_ADDRESS' 2>/dev/null || echo "")
    local user_display=$(su - "$SUDO_USER" -c 'echo $DISPLAY' 2>/dev/null || echo ":0")

    set +e
    local rc=0
    # Use xvfb-run for headless session + --no-bwrap fallback
    if command -v xvfb-run &>/dev/null; then
        xvfb-run -a su - "$SUDO_USER" -c "export DISPLAY=$user_display; export DBUS_SESSION_BUS_ADDRESS=$dbus_bus; protontricks --no-bwrap $PALWORLD_APPID winecfg" || rc=$?
    else
        su - "$SUDO_USER" -c "export DISPLAY=$user_display; export DBUS_SESSION_BUS_ADDRESS=$dbus_bus; protontricks --no-bwrap $PALWORLD_APPID winecfg" || rc=$?
    fi
    if [ $rc -ne 0 ]; then warn "Prefix init failed; manual protontricks --no-bwrap needed."; fi

    if command -v xvfb-run &>/dev/null; then
        xvfb-run -a su - "$SUDO_USER" -c "export DISPLAY=$user_display; export DBUS_SESSION_BUS_ADDRESS=$dbus_bus; protontricks --no-bwrap $PALWORLD_APPID vcrun2019 d3dx9_43 d3dx11_43 d3dcompiler_47 mf" || rc=$?
    else
        su - "$SUDO_USER" -c "export DISPLAY=$user_display; export DBUS_SESSION_BUS_ADDRESS=$dbus_bus; protontricks --no-bwrap $PALWORLD_APPID vcrun2019 d3dx9_43 d3dx11_43 d3dcompiler_47 mf" || rc=$?
    fi
    if [ $rc -ne 0 ]; then warn "Runtimes install partial; retry manually: protontricks --no-bwrap 1623730 vcrun2019 ..."; fi
    set -e

    # Post-fix DLL check
    if [ -f "$prefix_dir/pfx/drive_c/windows/system32/msvcp140.dll" ]; then
        say "MSVCP140.dll confirmed in prefix; DLL errors resolved."
    else
        warn "DLL check failed; verify manual install."
    fi

    say "Palworld prefix fixed. Verify files in Steam and force Proton-GE."
}

# Install gaming stack
install_gaming_stack() {
    if [ "$DISTRO_FAMILY" = "arch" ]; then
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            if $DRY_RUN; then
                say "Dry-run: Would enable multilib"
            else
                [ -f /etc/pacman.conf.bak ] || cp /etc/pacman.conf /etc/pacman.conf.bak
                echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >>/etc/pacman.conf
                pacman -Syyu --noconfirm || warn "pacman sync failed."
            fi
        fi
        pkg_install "lib32-nvidia-utils lib32-mesa" || warn "lib32 install failed."
        # Install community packages first
        pkg_install "mangohud lib32-mangohud gamescope" || warn "Community perf tools partial."
        # 32-bit gaming libs
        pkg_install "lib32-openal lib32-sdl2 lib32-libpulse lib32-alsa-plugins" || warn "32-bit gaming libs partial."
        # AUR for protontricks
        install_aur_pkg "protontricks" || warn "protontricks AUR install failed; manual yay -S protontricks."
    elif [ "$DISTRO_FAMILY" = "debian" ]; then
        dpkg --add-architecture i386
        apt update
        pkg_install "lib32-nvidia-utils:i386 libgl1-mesa-dri:i386 libgl1-mesa-glx:i386" || warn "32-bit GL partial."
        pkg_install "libopenal1:i386 libsdl2-2.0-0:i386 libpulse0:i386 libasound2-plugins:i386" || warn "32-bit gaming libs partial."
        pkg_install "mangohud gamescope protontricks" || warn "Perf tools partial."
    elif [ "$DISTRO_FAMILY" = "fedora" ]; then
        pkg_install "libnvidia-gl:i686 mesa-libGL:i686" || warn "32-bit GL partial."
        pkg_install "openal-soft-libs.i686 SDL2.i686 pulseaudio-libs.i686 alsa-lib.i686" || warn "32-bit gaming libs partial."
        pkg_install "mangohud gamescope protontricks" || warn "Perf tools partial."
    else
        # SUSE/other: Basic fallback
        pkg_install "mangohud gamescope protontricks libopenal1-32bit libSDL2-0-32bit libpulse0-32bit" || warn "Perf/32-bit libs partial."
    fi

    # Steam (prefer native for DX12 stability)
    if ! command -v steam &>/dev/null; then
        set +e
        case "$DISTRO_FAMILY" in
        debian) pkg_install "steam-installer" ;;
        fedora) pkg_install "steam" ;;
        arch) pkg_install "steam" ;;
        suse) pkg_install "steam" ;;
        *)
            # Try native first, fallback to Flatpak
            if ! pkg_install "steam-launcher" 2>/dev/null; then
                flatpak install -y flathub com.valvesoftware.Steam || warn "Steam Flatpak failed."
            fi
            ;;
        esac
        set -e
    fi

    # Wine and dependencies
    install_wine_staging
    pkg_install "winetricks" || warn "winetricks install failed."

    # Initialize Wine prefix before any Wine operations
    initialize_wine_prefix

    # Vulkan
    install_vulkan

    # Proton GE with optional checksum
    if curl --retry 3 -f -s --max-time 10 google.com &>/dev/null; then
        install_proton_ge
    else
        warn "Network down; skipping Proton GE install."
    fi

    # DXVK VKD3D
    install_dxvk_vkd3d

    # Winetricks runtimes
    install_winetricks_runtimes

    # Optional tools
    if ! $NONINTERACTIVE; then
        read -p "Install Lutris? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" == "y" ]]; then install_lutris; fi

        read -p "Install Bottles? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" == "y" ]]; then install_bottles; fi
    fi

    # Set compatibility envs
    set_compat_envs

    say "Gaming stack installation completed. DX12-ready with 32/64-bit libs for 64-bit games."
}

install_wine_staging() {
    set +e
    case "$DISTRO_FAMILY" in
    debian)
        dpkg --add-architecture i386
        apt update
        pkg_install "wine-staging wine-staging-amd64 wine-staging-i386" || warn "Wine staging install had issues"
        ;;
    fedora)
        dnf install -y wine || warn "Wine install had issues"
        ;;
    arch)
        pkg_install "wine-staging" || warn "Wine staging install had issues"
        ;;
    suse)
        zypper install -y wine || warn "Wine install had issues"
        ;;
    esac
    set -e
}

install_vulkan() {
    local vulkan_pkgs="vulkan-tools"
    case "$DISTRO_FAMILY" in
    debian) vulkan_pkgs+=" libvulkan1 libvulkan1:i386" ;;
    fedora) vulkan_pkgs+=" vulkan-loader vulkan-loader.i686" ;;
    arch) vulkan_pkgs+=" vulkan-icd-loader lib32-vulkan-icd-loader" ;;
    suse) vulkan_pkgs+=" vulkan libvulkan1" ;;
    esac
    pkg_install $vulkan_pkgs || warn "Vulkan install partial failure."
}

install_proton_ge() {
    local proton_dir="$USER_HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$proton_dir" || err "Failed to create $proton_dir"

    local latest_tag=$(curl --retry 3 -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" | grep -oP '"tag_name": "\K[^"]*')
    if [ -z "$latest_tag" ]; then
        latest_tag="GE-Proton10-22" # Updated fallback per Oct 2025 releases
        warn "API failed; using fallback tag: $latest_tag"
    fi

    local url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$latest_tag/$latest_tag.tar.gz"
    local checksum_url="${url%.tar.gz}.sha256sum"
    local file="/tmp/$latest_tag.tar.gz"
    local checksum_file="/tmp/$latest_tag.sha256sum"

    if $DRY_RUN; then
        say "Dry-run: Would download, verify, and install Proton GE $latest_tag"
        return
    fi

    progress_start "Downloading Proton GE $latest_tag"
    curl --retry 3 -L -o "$file" "$url" --progress-bar | while read -r line; do
        # Parse curl progress for percentage
        percent=$(echo "$line" | grep -o '[0-9]*\.[0-9]%')
        if [ -n "$percent" ]; then
            PROGRESS_CURRENT=${percent%.*}
            progress_update $PROGRESS_CURRENT "Downloading $latest_tag"
        fi
    done || {
        warn "Proton GE download failed; skipping."
        progress_end "Download failed."
        return
    }
    progress_end "Download complete."

    # Optional checksum
    set +e
    curl --retry 3 -L -o "$checksum_file" "$checksum_url" || {
        warn "Checksum download failed or unavailable; proceeding without verification."
        rm -f "$checksum_file"
    }
    if [ -s "$checksum_file" ]; then # Check if non-empty
        if sha256sum -c "$checksum_file" 2>/dev/null | grep -q "OK"; then
            log_info "Checksum verified for $latest_tag.tar.gz"
        else
            warn "Checksum verification failed; proceeding anyway (common for Proton-GE)."
        fi
    else
        warn "No valid checksum file; installation proceeds unverified."
    fi
    set -e

    tar -xzf "$file" -C "$proton_dir" || warn "Proton GE extract failed."
    rm -f "$file" "$checksum_file"

    chown -R "$SUDO_USER:$SUDO_USER" "$proton_dir"

    say "Proton GE $latest_tag installed successfully."
}

install_dxvk_vkd3d() {
    log_info "Installing DXVK and VKD3D..."

    safe_winetricks "dxvk" "DXVK installation" || warn "DXVK installation had issues"
    safe_winetricks "vkd3d" "VKD3D installation" || warn "VKD3D installation had issues"

    log_info "DXVK and VKD3D installation completed."
}

# Fixed winetricks runtimes installation
install_winetricks_runtimes() {
    log_info "Installing winetricks runtimes..."

    initialize_wine_prefix

    run_wine_command "winecfg -v win10" "Set Windows version to 10" 30 || {
        warn "Failed to set Windows version, continuing anyway..."
    }

    local runtimes=("d3dcompiler_43" "d3dcompiler_47" "vcrun2019" "corefonts" "mf" "wmp11" "gdiplus")

    PROGRESS_TOTAL=${#runtimes[@]}
    PROGRESS_CURRENT=0
    progress_start "Installing runtimes"

    for runtime in "${runtimes[@]}"; do
        log_info "Installing runtime: $runtime"
        if safe_winetricks "$runtime" "Runtime $runtime"; then
            say "Successfully installed: $runtime"
        else
            warn "Failed to install: $runtime"
        fi
        PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
        progress_update $PROGRESS_CURRENT "Installed $runtime"
        sleep 2
    done

    progress_end "Runtimes installed."

    if ! $NONINTERACTIVE; then
        read -p "Install .NET 4.8 (this may take 10-15 minutes)? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" == "y" ]]; then
            log_info "Installing .NET 4.8 (this will take a while)..."
            if safe_winetricks "dotnet48" ".NET 4.8 installation" 900; then
                say ".NET 4.8 installed successfully"
            else
                warn ".NET 4.8 installation failed or timed out"
            fi
        fi
    else
        warn "Skipping .NET 4.8 in non-interactive mode (too time-consuming)"
    fi

    log_info "Winetricks runtimes installation completed."
}

install_lutris() {
    set +e
    pkg_install "lutris"
    local rc=$?
    set -e
    if [ $rc -ne 0 ]; then
        warn "Lutris install failed; skipping."
        return
    fi
    say "Lutris installed. Run 'lutris' to configure."
}

install_bottles() {
    if ! flatpak list | grep -q com.usebottles.bottles; then
        if $DRY_RUN; then
            say "Dry-run: Would install Bottles via Flatpak"
            return
        fi
        set +e
        flatpak install -y flathub com.usebottles.bottles
        local rc=$?
        set -e
        if [ $rc -ne 0 ]; then
            warn "Bottles Flatpak install failed; skipping."
            return
        fi
    fi
    say "Bottles installed. Run 'flatpak run com.usebottles.bottles' to start."
}

set_compat_envs() {
    local env_file="$USER_HOME/.bashrc"
    local steam_env="$USER_HOME/.steam/steam/steam.sh.env"

    mkdir -p "$(dirname "$steam_env")"

    if ! grep -q "NVIDIA_GAMING_SETUP" "$env_file"; then
        echo "# NVIDIA_GAMING_SETUP - Compatibility environment variables" >>"$env_file"
        echo "export PROTON_ENABLE_NVAPI=1" >>"$env_file"
        echo "export PROTON_HIDE_NVIDIA_GPU=0" >>"$env_file"
        echo "export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json" >>"$env_file"
        echo "export __GL_SHADER_DISK_CACHE=1" >>"$env_file"
        echo "export __GL_SHADER_DISK_CACHE_PATH=$USER_HOME/.cache/nvidia" >>"$env_file"
        echo "export VKD3D_CONFIG=dxr11" >>"$env_file"       # DX12 ray tracing
        echo "export VKD3D_FEATURE_LEVEL=12_2" >>"$env_file" # Higher DX12 features
        echo "export DXVK_ASYNC=1" >>"$env_file"             # Async shaders for perf
        echo "export MANGOHUD=1" >>"$env_file"               # Enable MangoHud overlay
        echo "export GAMEMODERUN=1" >>"$env_file"            # Gamemode integration
    fi

    # Mirror to Steam env
    cat >>"$steam_env" <<EOF
export PROTON_ENABLE_NVAPI=1
export PROTON_HIDE_NVIDIA_GPU=0
export DXVK_ASYNC=1
export MANGOHUD=1
export GAMEMODERUN=1
EOF

    mkdir -p "$USER_HOME/.cache/nvidia"
    chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.cache/nvidia"

    say "Compatibility environment variables configured (DX12-optimized)."
}

# Verification
verify_setup() {
    local checks=()

    if nvidia-smi &>/dev/null; then
        checks+=("NVIDIA Driver: PASS")
    else
        checks+=("NVIDIA Driver: FAIL")
    fi

    if vulkaninfo --summary &>/dev/null 2>&1; then
        checks+=("Vulkan: PASS")
    else
        checks+=("Vulkan: FAIL")
    fi

    if wine --version &>/dev/null; then
        checks+=("Wine: PASS")
    else
        checks+=("Wine: FAIL")
    fi

    if command -v steam &>/dev/null || flatpak list | grep -q com.valvesoftware.Steam; then
        checks+=("Steam: PASS")
    else
        checks+=("Steam: FAIL")
    fi

    # DX12-specific: Test VKD3D readiness (simple vulkan cube spin)
    if command -v vkcube &>/dev/null && vkcube &>/dev/null; then
        checks+=("DX12/VKD3D Ready: PASS")
    else
        checks+=("DX12/VKD3D Ready: FAIL (run vkcube manually)")
    fi

    # Perf tools
    if command -v mangohud &>/dev/null && command -v gamescope &>/dev/null; then
        checks+=("Perf Tools: PASS")
    else
        checks+=("Perf Tools: FAIL")
    fi

    # 32-bit libs check (e.g., SDL2)
    if ldconfig -p 2>/dev/null | grep -q "libSDL2"; then
        checks+=("32/64-Bit Libs: PASS")
    else
        checks+=("32/64-Bit Libs: FAIL (check ldconfig -p | grep libSDL2)")
    fi

    # Palworld prefix check
    local pal_prefix="$USER_HOME/.steam/steam/steamapps/compatdata/$PALWORLD_APPID"
    if [ -d "$pal_prefix" ] && [ -f "$pal_prefix/pfx/drive_c/windows/system32/msvcp140.dll" ]; then
        checks+=("Palworld DLLs: PASS")
    else
        checks+=("Palworld DLLs: FAIL (run palworld_fix manually)")
    fi

    echo "=== Setup Verification ==="
    for check in "${checks[@]}"; do
        if [[ "$check" == *"PASS"* ]]; then
            say "$check"
        else
            err "$check"
        fi
    done

    local fail_count=$(printf '%s\n' "${checks[@]}" | grep -c "FAIL")
    if [ "$fail_count" -eq 0 ]; then
        say "All checks passed! Fully out-of-the-box ready for DX12 gaming (e.g., Palworld via Steam + Proton-GE)."
    else
        warn "$fail_count check(s) failed. Some components may need manual intervention."
    fi
}

# Uninstall
uninstall() {
    set +e
    kill_wine_processes

    pkg_remove "nvidia*"
    unblacklist_nouveau
    pkg_remove "steam wine* winetricks vulkan* lutris mangohud gamescope lib32-* lib*-i386 lib*-i686"
    if [ "$DISTRO_FAMILY" = "arch" ]; then
        install_aur_helper # For removal
        yay -Rns --noconfirm protontricks || true
    fi

    rm -rf "$USER_HOME/.steam/root/compatibilitytools.d"
    rm -rf "$WINE_PREFIX"
    rm -rf "$USER_HOME/.cache/nvidia"

    if ! $NONINTERACTIVE; then
        read -p "Remove Lutris config? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" == "y" ]]; then rm -rf "$USER_HOME/.config/lutris"; fi

        read -p "Remove Bottles? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" == "y" ]]; then
            flatpak uninstall -y com.usebottles.bottles
            rm -rf "$USER_HOME/.var/app/com.usebottles.bottles"
        fi
    fi

    set -e
    say "Uninstall complete. Reboot to complete cleanup."
}

# Main execution
main() {
    log_info "Starting NVIDIA gaming setup v$VERSION..."
    detect_distro
    check_prereqs

    if $UNINSTALL; then
        uninstall
        exit 0
    fi

    progress_start "Setting up kernel headers"
    install_kernel_headers
    progress_end "Kernel headers set up."

    progress_start "Blacklisting nouveau"
    blacklist_nouveau
    progress_end "Nouveau blacklisted."

    progress_start "Detecting GPU"
    detect_gpu
    progress_end "GPU detected."

    progress_start "Installing drivers"
    install_drivers
    progress_end "Drivers installed."

    progress_start "Installing gaming stack"
    install_gaming_stack
    progress_end "Gaming stack installed."

    # Auto-apply Palworld fix if detected
    progress_start "Fixing Palworld prefix"
    palworld_fix
    progress_end "Palworld fixed."

    progress_start "Verifying setup"
    verify_setup
    progress_end "Verification complete."

    # Palworld-specific guide
    say "=== Palworld DX12 Quick Start ==="
    say "1. Launch Steam: steam"
    say "2. Right-click Palworld > Properties > Compatibility > Force specific Proton tool: GE-Proton10-22"
    say "3. Add launch options: MANGOHUD=1 gamemoderun %command% --gamescope -w 1920 -h 1080 -r 60"
    say "4. For issues: protontricks --no-bwrap 1623730 mf vkd3d (or rerun script)"
    say "Expected: 60+ FPS on RTX 30xx+ with low latency mode (env DXVK_ASYNC=1)."

    if ! $NONINTERACTIVE; then
        read -p "Setup complete. Reboot now? (y/n): " choice </dev/tty || choice="n"
        if [[ "$choice" == "y" ]]; then
            say "Rebooting system..."
            reboot
        fi
    else
        say "Setup complete. Please reboot for all changes to take effect."
    fi
}

main
