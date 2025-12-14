#!/bin/bash

# Arch Linux Toolbox
# Author: Claude
# Description: Comprehensive Arch Linux management and repair toolkit

# Script directory and metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"
SCRIPT_NAME="Arch Linux Toolbox"
EXTRAS_MIN_VERSION="1.0.0"

# Set strict error handling
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
CHECK_ICON="✓"
ERROR_ICON="✗"
INFO_ICON="ℹ"
WARN_ICON="⚠"
TOOL_ICON="🔧"
DESKTOP_ICON="🖥"
SYSTEM_ICON="⚙"
REPAIR_ICON="🔨"

# Logging configuration
LOG_DIR="/var/log/arch-toolbox"
INSTALL_LOG="${LOG_DIR}/install.log"
ERROR_LOG="${LOG_DIR}/error.log"
REPAIR_LOG="${LOG_DIR}/repair.log"
DEBUG_LOG="${LOG_DIR}/debug.log"

# Initialize logging
setup_logging() {
    # Check if we can create/access the log directory
    if [ ! -d "$LOG_DIR" ]; then
        sudo mkdir -p "$LOG_DIR" || {
            echo -e "${RED}${ERROR_ICON} Failed to create log directory${NC}"
            exit 1
        }
    fi
    
    # Set correct permissions
    sudo chown -R $USER:$USER "$LOG_DIR" || {
        echo -e "${RED}${ERROR_ICON} Failed to set log directory permissions${NC}"
        exit 1
    }
    
    sudo chmod 755 "$LOG_DIR" || {
        echo -e "${RED}${ERROR_ICON} Failed to set log directory mode${NC}"
        exit 1
    }
    
    # Create log files with proper permissions
    for log_file in "$INSTALL_LOG" "$ERROR_LOG" "$REPAIR_LOG" "$DEBUG_LOG"; do
        if [ ! -f "$log_file" ]; then
            touch "$log_file" || {
                echo -e "${RED}${ERROR_ICON} Failed to create log file: $log_file${NC}"
                exit 1
            }
            chmod 644 "$log_file" || {
                echo -e "${RED}${ERROR_ICON} Failed to set log file permissions: $log_file${NC}"
                exit 1
            }
        fi
    done
    
    # Rotate logs if they exceed size limit
    for log_file in "$INSTALL_LOG" "$ERROR_LOG" "$REPAIR_LOG" "$DEBUG_LOG"; do
        if [ -f "$log_file" ] && [ "$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file")" -gt $((10*1024*1024)) ]; then
            mv "$log_file" "$log_file.old"
            touch "$log_file"
            chmod 644 "$log_file"
        fi
    done
    
    # Set up log redirection
    exec 1> >(tee -a "$INSTALL_LOG")
    exec 2> >(tee -a "$ERROR_LOG")
    
    print_success "Logging initialized successfully"
}

# Script metadata
VERSION="1.0.0"
SCRIPT_NAME="Arch Linux Toolbox"
EXTRAS_MIN_VERSION="1.0.0"

# Initialize script
initialize_script() {
    # Run initial setup
    initial_setup || {
        print_error "Initial setup failed"
        exit 1
    }

    # Setup logging
    setup_logging || {
        print_error "Failed to setup logging"
        exit 1
    }

    # Verify extras script
    if [ ! -f "$SCRIPT_DIR/arch-toolbox-extras.sh" ]; then
        print_error "Extras script not found"
        exit 1
    }

    # Source extras script
    source "$SCRIPT_DIR/arch-toolbox-extras.sh" || {
        print_error "Failed to source extras script"
        exit 1
    }

    # Verify script versions are compatible
    if ! check_version_compatibility; then
        print_error "Extras script version is incompatible"
        exit 1
    }

    print_success "Initialization complete"
}

# Version compatibility check
check_version_compatibility() {
    if [ -z "$EXTRAS_VERSION" ]; then
        return 1
    fi
    
    local min_version=$EXTRAS_MIN_VERSION
    local current_version=$EXTRAS_VERSION
    
    if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" != "$min_version" ]; then
        return 1
    fi
    
    return 0
}

# Validate configuration
validate_config() {
    local config_file=$1
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        return 1
    }
    
    case "$config_file" in
        *.conf)
            # Basic syntax check for config files
            grep -v '^#' "$config_file" | grep -v '^$' | while IFS= read -r line; do
                if ! echo "$line" | grep -q '^[a-zA-Z0-9_.-]\+ \?= \?.*$'; then
                    print_error "Invalid configuration line: $line"
                    return 1
                fi
            done
            ;;
        *.json)
            # JSON validation
            if ! jq empty "$config_file" 2>/dev/null; then
                print_error "Invalid JSON configuration"
                return 1
            fi
            ;;
        *)
            print_warning "Unknown configuration file type: $config_file"
            return 0
            ;;
    esac
    
    return 0
}

# Verify backup
verify_backup() {
    local backup_file=$1
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    }
    
    # Check if it's a valid tar.gz file
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        print_error "Invalid backup archive: $backup_file"
        return 1
    }
    
    # Check backup contents
    local required_files=("hypr" "waybar" ".zshrc")
    for file in "${required_files[@]}"; do
        if ! tar -tzf "$backup_file" | grep -q "$file"; then
            print_warning "Missing expected file in backup: $file"
        fi
    done
    
    print_success "Backup verification complete"
    return 0
}

# Run initialization
initialize_script

# Error handling functions
handle_error() {
    local error_code=$1
    local error_message=$2
    local function_name=$3
    
    print_error "Error in $function_name: $error_message (Code: $error_code)"
    log_error "$function_name failed with error code $error_code: $error_message"
    
    case $error_code in
        1) print_error "General error occurred" ;;
        2) print_error "Package installation failed" ;;
        3) print_error "Configuration error" ;;
        4) print_error "Permission denied" ;;
        5) print_error "Network error" ;;
        6) print_error "Dependency missing" ;;
        *) print_error "Unknown error occurred" ;;
    esac
    
    if [ "$ENABLE_ROLLBACK" = true ]; then
        perform_rollback "$function_name"
    fi
}

perform_rollback() {
    local function_name=$1
    print_warning "Attempting to rollback changes from $function_name..."
    
    case $function_name in
        "optimize_gaming")
            print_info "Rolling back gaming optimizations..."
            sudo systemctl stop gamemoded
            sudo systemctl disable gamemoded
            ;;
        "setup_dev_environment")
            print_info "Rolling back development environment..."
            # Specific rollback steps would go here
            ;;
        "customize_hyprland_advanced")
            print_info "Rolling back Hyprland customizations..."
            if [ -f ~/.config/hypr/hyprland.conf.backup ]; then
                mv ~/.config/hypr/hyprland.conf.backup ~/.config/hypr/hyprland.conf
            fi
            ;;
        *)
            print_warning "No specific rollback procedure for $function_name"
            ;;
    esac
    
    print_info "Rollback complete"
}

check_dependencies() {
    local deps=("$@")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_info "Installing missing dependencies..."
        sudo pacman -S --noconfirm "${missing_deps[@]}" || {
            handle_error 6 "Failed to install dependencies" "check_dependencies"
            return 1
        }
    fi
    
    return 0
}

verify_network() {
    if ! ping -c 1 archlinux.org >/dev/null 2>&1; then
        handle_error 5 "No network connection" "verify_network"
        return 1
    fi
    return 0
}

verify_permissions() {
    if [ "$(id -u)" = 0 ]; then
        handle_error 4 "Script must not be run as root" "verify_permissions"
        return 1
    fi
    
    if ! sudo -v; then
        handle_error 4 "Sudo access required" "verify_permissions"
        return 1
    fi
    
    return 0
}

# Enable error handling
set -E
trap 'handle_error $? "An error occurred on line $LINENO" "${FUNCNAME[0]}"' ERR

# Logging functions
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [INFO] $1" | tee -a "$INSTALL_LOG"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [ERROR] $1" | tee -a "$ERROR_LOG"
}

log_repair() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [REPAIR] $1" | tee -a "$REPAIR_LOG"
}

log_debug() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [DEBUG] $1" | tee -a "$DEBUG_LOG"
}

# Print functions
print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}\n"
}

print_info() {
    echo -e "${BLUE}${INFO_ICON} $1${NC}"
    log_info "$1"
}

print_success() {
    echo -e "${GREEN}${CHECK_ICON} $1${NC}"
    log_info "[SUCCESS] $1"
}

print_error() {
    echo -e "${RED}${ERROR_ICON} $1${NC}"
    log_error "$1"
}

print_warning() {
    echo -e "${YELLOW}${WARN_ICON} $1${NC}"
    log_info "[WARNING] $1"
}

# System detection functions
detect_system_type() {
    if [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

detect_desktop_environment() {
    if pgrep -x "hyprland" >/dev/null; then
        echo "hyprland"
    elif [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
        echo "hyprland"
    else
        echo "unknown"
    fi
}

detect_gpu() {
    if lspci | grep -i "nvidia" >/dev/null; then
        echo "nvidia"
    elif lspci | grep -i "amd" >/dev/null; then
        echo "amd"
    elif lspci | grep -i "intel" >/dev/null; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# System health check functions
check_system_health() {
    print_header "System Health Check"
    local issues=0

    # Check disk space
    print_info "Checking disk space..."
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        print_warning "Low disk space: ${disk_usage}% used"
        ((issues++))
    fi

    # Check memory usage
    print_info "Checking memory usage..."
    local mem_usage=$(free | awk '/Mem:/ {printf("%.0f", $3/$2 * 100)}')
    if [ "$mem_usage" -gt 90 ]; then
        print_warning "High memory usage: ${mem_usage}%"
        ((issues++))
    fi

    # Check system load
    print_info "Checking system load..."
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    local cores=$(nproc)
    if [ "$(echo "$load > $cores" | bc)" -eq 1 ]; then
        print_warning "High system load: $load (cores: $cores)"
        ((issues++))
    fi

    # Check failed services
    print_info "Checking systemd services..."
    local failed_services=$(systemctl --failed --no-pager)
    if [ -n "$failed_services" ]; then
        print_warning "Failed services found:"
        echo "$failed_services"
        ((issues++))
    fi

    # Check for system updates
    print_info "Checking for system updates..."
    local updates=$(checkupdates 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        print_warning "$updates system updates available"
        ((issues++))
    fi

    # Check journal errors
    print_info "Checking system logs..."
    local journal_errors=$(journalctl -p err..alert --since "24 hours ago" --no-pager | wc -l)
    if [ "$journal_errors" -gt 0 ]; then
        print_warning "$journal_errors errors found in system logs (last 24h)"
        ((issues++))
    fi

    # Check disk health
    print_info "Checking disk health..."
    if command -v smartctl &>/dev/null; then
        for disk in /dev/sd[a-z] /dev/nvme[0-9]n[1-9]; do
            if [ -b "$disk" ]; then
                local smart_status=$(sudo smartctl -H "$disk" | grep "SMART overall-health")
                if ! echo "$smart_status" | grep -q "PASSED"; then
                    print_warning "Disk $disk health check failed"
                    ((issues++))
                fi
            fi
        done
    fi

    # Summary
    if [ "$issues" -eq 0 ]; then
        print_success "System health check completed: No issues found"
    else
        print_warning "System health check completed: $issues issue(s) found"
    fi
}

# Hyprland repair function
repair_hyprland() {
    print_header "Hyprland Repair"
    
    print_info "Checking Hyprland installation..."
    
    # Verify Hyprland installation
    if ! command -v hyprland &>/dev/null; then
        print_error "Hyprland not found. Installing..."
        sudo pacman -S --noconfirm hyprland || {
            print_error "Failed to install Hyprland"
            return 1
        }
    fi
    
    # Backup existing configuration
    print_info "Backing up existing configuration..."
    local timestamp=$(date +%Y%m%d_%H%M%S)
    if [ -d ~/.config/hypr ]; then
        mv ~/.config/hypr ~/.config/hypr.backup_$timestamp
    fi
    
    # Reinstall dependencies
    print_info "Reinstalling dependencies..."
    sudo pacman -S --noconfirm --needed \
        hyprland \
        waybar \
        wofi \
        dunst \
        polkit-gnome \
        swayidle \
        swaylock \
        wl-clipboard \
        grim \
        slurp \
        hyprpaper
    
    # Reset configuration
    print_info "Resetting configuration..."
    mkdir -p ~/.config/hypr
    cp /etc/hypr/hyprland.conf ~/.config/hypr/ 2>/dev/null || {
        print_warning "Default config not found, creating new one..."
        cat > ~/.config/hypr/hyprland.conf <<EOL
# Default Hyprland configuration
monitor=,preferred,auto,1

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    layout = dwindle
}

decoration {
    rounding = 10
}

animations {
    enabled = true
}

dwindle {
    pseudotile = true
    preserve_split = true
}

bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, dolphin
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,

bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
EOL
    }
    
    # Reset Waybar configuration
    print_info "Resetting Waybar configuration..."
    mkdir -p ~/.config/waybar
    cp -r /etc/xdg/waybar/* ~/.config/waybar/ 2>/dev/null || {
        print_warning "Default Waybar config not found, creating new one..."
        customize_hyprland_advanced
    }
    
    # Fix permissions
    print_info "Fixing permissions..."
    chmod -R u+w ~/.config/hypr
    chmod -R u+w ~/.config/waybar
    
    # Restart Hyprland
    print_info "Configuration reset complete"
    print_success "Please restart Hyprland to apply changes"
}

# System repair function
repair_system() {
    print_header "System Repair"
    
    # Check filesystem
    print_info "Checking filesystem..."
    sudo fsck -f / || print_warning "Filesystem check failed"
    
    # Rebuild initramfs
    print_info "Rebuilding initramfs..."
    sudo mkinitcpio -P || print_warning "Initramfs rebuild failed"
    
    # Rebuild grub config
    if [ -d /sys/firmware/efi ]; then
        print_info "Rebuilding GRUB configuration..."
        sudo grub-mkconfig -o /boot/grub/grub.cfg || print_warning "GRUB config rebuild failed"
    fi
    
    # Fix package database
    print_info "Fixing package database..."
    sudo rm -f /var/lib/pacman/db.lck
    sudo pacman -Syy || print_warning "Package database sync failed"
    
    # Check for broken packages
    print_info "Checking for broken packages..."
    sudo pacman -Dk || {
        print_warning "Found broken packages, attempting to fix..."
        sudo pacman -D --asexplicit base linux linux-firmware
    }
    
    # Reinstall base packages
    print_info "Reinstalling base packages..."
    sudo pacman -S --noconfirm base base-devel || print_warning "Base package reinstall failed"
    
    # Fix permissions
    print_info "Fixing permissions..."
    sudo chown -R $USER:$USER $HOME
    sudo chmod -R u+rw $HOME
    
    # Clear package cache
    print_info "Clearing package cache..."
    sudo paccache -r
    
    # Clear journal logs
    print_info "Clearing old journal logs..."
    sudo journalctl --vacuum-time=2d
    
    print_success "System repair complete"
}

# Backup configuration function
backup_config() {
    print_header "Configuration Backup"
    
    # Create backup directory
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$HOME/.config/backups/backup_$timestamp"
    mkdir -p "$backup_dir"
    
    # Backup Hyprland config
    if [ -d "$HOME/.config/hypr" ]; then
        print_info "Backing up Hyprland configuration..."
        cp -r "$HOME/.config/hypr" "$backup_dir/"
    fi
    
    # Backup Waybar config
    if [ -d "$HOME/.config/waybar" ]; then
        print_info "Backing up Waybar configuration..."
        cp -r "$HOME/.config/waybar" "$backup_dir/"
    fi
    
    # Backup shell config
    if [ -f "$HOME/.zshrc" ]; then
        print_info "Backing up shell configuration..."
        cp "$HOME/.zshrc" "$backup_dir/"
    fi
    
    # Backup other configs
    for config in dunst wofi kitty alacritty neofetch; do
        if [ -d "$HOME/.config/$config" ]; then
            print_info "Backing up $config configuration..."
            cp -r "$HOME/.config/$config" "$backup_dir/"
        fi
    done
    
    # Create backup archive
    tar -czf "$backup_dir.tar.gz" -C "$backup_dir" .
    rm -rf "$backup_dir"
    print_success "Created backup archive at $backup_dir.tar.gz"
}

# Configuration restore functions
restore_config() {
    print_header "Configuration Restore"
    
    # List available backups
    local backup_dir="$HOME/.config/backups"
    if [ ! -d "$backup_dir" ]; then
        print_error "No backups found"
        return 1
    fi

    print_info "Available backups:"
    ls -1 "$backup_dir"/*.tar.gz 2>/dev/null | nl

    # Select backup to restore
    read -rp "Enter backup number to restore: " backup_num
    local backup_file=$(ls -1 "$backup_dir"/*.tar.gz 2>/dev/null | sed -n "${backup_num}p")

    if [ ! -f "$backup_file" ]; then
        print_error "Invalid backup selection"
        return 1
    fi

    # Create temporary directory
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"

    # Restore configurations
    if [ -d "$temp_dir/hypr" ]; then
        cp -r "$temp_dir/hypr" "$HOME/.config/"
        print_success "Restored Hyprland configuration"
    fi

    if [ -d "$temp_dir/waybar" ]; then
        cp -r "$temp_dir/waybar" "$HOME/.config/"
        print_success "Restored Waybar configuration"
    fi

    if [ -f "$temp_dir/.zshrc" ]; then
        cp "$temp_dir/.zshrc" "$HOME/"
        print_success "Restored shell configuration"
    fi

    # Cleanup
    rm -rf "$temp_dir"
    print_success "Configuration restore complete"
}

# System optimization functions
optimize_system() {
    print_header "System Optimization"

    # Optimize pacman
    print_info "Optimizing package manager..."
    sudo pacman -Sc --noconfirm
    sudo pacman-optimize
    sudo paccache -r

    # Optimize system settings
    print_info "Optimizing system settings..."
    echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-sysctl.conf
    echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-sysctl.conf

    # Enable periodic TRIM
    print_info "Enabling periodic TRIM..."
    sudo systemctl enable fstrim.timer
    sudo systemctl start fstrim.timer

    # Optimize makepkg
    print_info "Optimizing build settings..."
    sudo sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf

    print_success "System optimization complete"
}

# Performance tuning functions
tune_performance() {
    print_header "Performance Tuning"
    
    # CPU Governor settings
    print_info "Configuring CPU governor..."
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
        echo "CPU governor set to performance mode"
    fi
    
    # I/O scheduler optimization
    print_info "Optimizing I/O scheduler..."
    for disk in /sys/block/sd*; do
        if [ -f "$disk/queue/scheduler" ]; then
            echo "mq-deadline" | sudo tee "$disk/queue/scheduler"
        fi
    done
    
    # Network optimization
    print_info "Optimizing network settings..."
    sudo tee /etc/sysctl.d/99-network-performance.conf > /dev/null <<EOL
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
EOL
    sudo sysctl -p /etc/sysctl.d/99-network-performance.conf
    
    print_success "Performance tuning complete"
}

# AUR management functions
manage_aur() {
    print_header "AUR Management"
    
    # Check if yay is installed
    if ! command -v yay &> /dev/null; then
        print_warning "yay not found, installing..."
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
    fi
    
    while true; do
        echo -e "\n${CYAN}AUR Management Options:${NC}"
        echo -e "${CYAN}1${NC}) Update AUR packages"
        echo -e "${CYAN}2${NC}) Clean AUR cache"
        echo -e "${CYAN}3${NC}) List installed AUR packages"
        echo -e "${CYAN}4${NC}) Search AUR packages"
        echo -e "${CYAN}5${NC}) Install AUR package"
        echo -e "${CYAN}6${NC}) Remove AUR package"
        echo -e "${CYAN}7${NC}) Return to main menu"
        
        read -rp "Enter your choice: " aur_choice
        case $aur_choice in
            1)
                print_info "Updating AUR packages..."
                yay -Syu --aur
                ;;
            2)
                print_info "Cleaning AUR cache..."
                yay -Sc --aur
                ;;
            3)
                print_info "Installed AUR packages:"
                yay -Qm
                ;;
            4)
                read -rp "Enter package name to search: " search_term
                yay -Ss "$search_term"
                ;;
            5)
                read -rp "Enter package name to install: " pkg_name
                yay -S "$pkg_name"
                ;;
            6)
                read -rp "Enter package name to remove: " pkg_name
                yay -Rns "$pkg_name"
                ;;
            7) break ;;
            *) print_error "Invalid choice" ;;
        esac
    done
}

# Advanced system maintenance
maintain_system() {
    print_header "System Maintenance"
    
    # Clean package cache
    print_info "Cleaning package cache..."
    sudo pacman -Sc --noconfirm
    yay -Sc --noconfirm
    
    # Remove orphaned packages
    print_info "Removing orphaned packages..."
    sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null || echo "No orphaned packages found."
    
    # Clean journal logs
    print_info "Cleaning journal logs..."
    sudo journalctl --vacuum-time=7d
    
    # Clean user cache
    print_info "Cleaning user cache..."
    rm -rf ~/.cache/*
    
    # Update mirrorlist
    print_info "Updating mirrorlist..."
    sudo reflector --country 'United States' --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    
    # Check for failed systemd units
    print_info "Checking systemd units..."
    systemctl --failed
    
    # Check disk health
    print_info "Checking disk health..."
    for disk in /dev/sd[a-z]; do
        if [ -b "$disk" ]; then
            sudo smartctl -H "$disk" || true
        fi
    done
    
    print_success "System maintenance complete"
}

# Security hardening
harden_system() {
    print_header "Security Hardening"
    
    # Install security tools
    print_info "Installing security tools..."
    sudo pacman -S --noconfirm ufw fail2ban arch-audit firejail apparmor
    
    # Configure firewall
    print_info "Configuring firewall..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable
    
    # Configure fail2ban
    print_info "Configuring fail2ban..."
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sudo systemctl enable --now fail2ban
    
    # Enable AppArmor
    print_info "Enabling AppArmor..."
    sudo systemctl enable --now apparmor
    
    # Secure SSH configuration
    if [ -f /etc/ssh/sshd_config ]; then
        print_info "Securing SSH configuration..."
        sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo systemctl restart sshd
    fi
    
    print_success "Security hardening complete"
}

# Gaming optimization functions
optimize_gaming() {
    print_header "Gaming Optimization"
    
    # Install gaming packages
    print_info "Installing gaming packages..."
    sudo pacman -S --noconfirm \
        gamemode \
        lib32-gamemode \
        mangohud \
        lib32-mangohud \
        steam \
        wine \
        wine-mono \
        wine-gecko \
        winetricks \
        lutris \
        vulkan-icd-loader \
        lib32-vulkan-icd-loader \
        vulkan-tools \
        proton-ge-custom

    # Configure Gamemode
    print_info "Configuring Gamemode..."
    sudo systemctl enable --now gamemoded
    
    # Configure GPU settings
    local gpu_type=$(detect_gpu)
    case $gpu_type in
        "nvidia")
            print_info "Configuring NVIDIA settings..."
            sudo pacman -S --noconfirm nvidia-settings
            # Enable performance mode
            sudo nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1"
            # Enable ForceFullCompositionPipeline
            nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 { ForceFullCompositionPipeline = On }"
            ;;
        "amd")
            print_info "Configuring AMD settings..."
            echo "AMD_VULKAN_ICD=RADV" | sudo tee -a /etc/environment
            # Set performance mode
            echo "performance" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
            ;;
    esac
    
    # Configure CPU governor for gaming
    print_info "Configuring CPU settings..."
    sudo tee /etc/gamemode.ini > /dev/null <<EOL
[general]
renice=10
softrealtime=auto
inhibit_screensaver=1

[cpu]
governor=performance
frequency_percent=100

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=auto
amd_performance_level=high
EOL

    # Install Proton-GE
    print_info "Installing Proton-GE..."
    mkdir -p ~/.steam/root/compatibilitytools.d/
    latest_proton=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep "browser_download_url.*tar.gz" | cut -d : -f 2,3 | tr -d \")
    wget "$latest_proton" -O /tmp/proton.tar.gz
    tar -xzf /tmp/proton.tar.gz -C ~/.steam/root/compatibilitytools.d/
    rm /tmp/proton.tar.gz

    print_success "Gaming optimization complete"
}

# Development environment setup
setup_dev_environment() {
    print_header "Development Environment Setup"
    
    while true; do
        echo -e "\n${CYAN}Development Environment Options:${NC}"
        echo -e "${CYAN}1${NC}) Install base development tools"
        echo -e "${CYAN}2${NC}) Setup Python development"
        echo -e "${CYAN}3${NC}) Setup Node.js development"
        echo -e "${CYAN}4${NC}) Setup Rust development"
        echo -e "${CYAN}5${NC}) Setup Go development"
        echo -e "${CYAN}6${NC}) Setup Docker environment"
        echo -e "${CYAN}7${NC}) Setup VSCode with extensions"
        echo -e "${CYAN}8${NC}) Setup Git configuration"
        echo -e "${CYAN}9${NC}) Return to main menu"
        
        read -rp "Enter your choice: " dev_choice
        case $dev_choice in
            1)
                print_info "Installing base development tools..."
                sudo pacman -S --noconfirm \
                    base-devel \
                    git \
                    cmake \
                    ninja \
                    gdb \
                    lldb \
                    clang \
                    llvm \
                    make \
                    autoconf \
                    automake \
                    pkg-config
                ;;
            2)
                print_info "Setting up Python development environment..."
                sudo pacman -S --noconfirm \
                    python \
                    python-pip \
                    python-virtualenv \
                    python-poetry \
                    pyenv \
                    python-pylint \
                    python-black \
                    python-pytest
                ;;
            3)
                print_info "Setting up Node.js development environment..."
                sudo pacman -S --noconfirm nodejs npm
                # Install nvm for Node.js version management
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
                # Install global npm packages
                npm install -g yarn typescript ts-node nodemon eslint prettier
                ;;
            4)
                print_info "Setting up Rust development environment..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                source $HOME/.cargo/env
                rustup component add rls rust-analysis rust-src
                rustup toolchain install nightly
                cargo install cargo-edit cargo-watch cargo-audit
                ;;
            5)
                print_info "Setting up Go development environment..."
                sudo pacman -S --noconfirm go
                # Set up Go workspace
                mkdir -p ~/go/{bin,src,pkg}
                echo 'export GOPATH=$HOME/go' >> ~/.zshrc
                echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
                # Install common Go tools
                go install golang.org/x/tools/gopls@latest
                go install golang.org/x/tools/cmd/goimports@latest
                ;;
            6)
                print_info "Setting up Docker environment..."
                sudo pacman -S --noconfirm docker docker-compose
                sudo systemctl enable --now docker
                sudo usermod -aG docker $USER
                # Install Docker tools
                sudo pacman -S --noconfirm lazydocker ctop
                ;;
            7)
                print_info "Setting up VSCode with extensions..."
                sudo pacman -S --noconfirm code
                # Install popular extensions
                code --install-extension ms-python.python
                code --install-extension dbaeumer.vscode-eslint
                code --install-extension esbenp.prettier-vscode
                code --install-extension rust-lang.rust-analyzer
                code --install-extension golang.go
                code --install-extension ms-azuretools.vscode-docker
                code --install-extension github.copilot
                ;;
            8)
                print_info "Setting up Git configuration..."
                read -rp "Enter your Git username: " git_username
                read -rp "Enter your Git email: " git_email
                git config --global user.name "$git_username"
                git config --global user.email "$git_email"
                git config --global core.editor "nvim"
                git config --global init.defaultBranch "main"
                # Install Git tools
                sudo pacman -S --noconfirm \
                    git-delta \
                    lazygit \
                    github-cli \
                    git-lfs
                ;;
            9) break ;;
            *) print_error "Invalid choice" ;;
        esac
    done
}

# Advanced Hyprland customization
customize_hyprland_advanced() {
    print_header "Advanced Hyprland Customization"
    
    while true; do
        echo -e "\n${CYAN}Advanced Customization Options:${NC}"
        echo -e "${CYAN}1${NC}) Install and configure themes"
        echo -e "${CYAN}2${NC}) Configure animations and effects"
        echo -e "${CYAN}3${NC}) Configure workspaces and layouts"
        echo -e "${CYAN}4${NC}) Configure gestures and input"
        echo -e "${CYAN}5${NC}) Configure autostart applications"
        echo -e "${CYAN}6${NC}) Configure Waybar advanced"
        echo -e "${CYAN}7${NC}) Configure window rules"
        echo -e "${CYAN}8${NC}) Configure keybindings"
        echo -e "${CYAN}9${NC}) Return to main menu"
        
        read -rp "Enter your choice: " custom_choice
        case $custom_choice in
            1)
                print_info "Installing and configuring themes..."
                # Install themes and dependencies
                yay -S --noconfirm \
                    catppuccin-gtk-theme-mocha \
                    catppuccin-cursors-mocha \
                    papirus-icon-theme \
                    nwg-look \
                    qt5ct \
                    kvantum
                
                # Configure GTK theme
                mkdir -p ~/.config/gtk-3.0
                cat > ~/.config/gtk-3.0/settings.ini <<EOL
[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Catppuccin-Mocha-Dark
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
EOL
                ;;
            2)
                print_info "Configuring animations and effects..."
                # Configure animations
                cat > ~/.config/hypr/animations.conf <<EOL
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = linear, 0.0, 0.0, 1.0, 1.0
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
    animation = specialWorkspace, 1, 6, myBezier, slidevert
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 5
        passes = 2
        new_optimizations = true
        ignore_opacity = true
    }
    drop_shadow = true
    shadow_range = 15
    shadow_offset = 3 3
    shadow_render_power = 2
    col.shadow = 0x66000000
}
EOL
                ;;
            3)
                print_info "Configuring workspaces and layouts..."
                # Configure workspaces
                cat > ~/.config/hypr/workspaces.conf <<EOL
# Workspace configuration
workspace = 1, monitor:DP-1, default:true, persistent:true
workspace = 2, monitor:DP-1
workspace = 3, monitor:DP-1
workspace = 4, monitor:DP-1
workspace = 5, monitor:HDMI-A-1, default:true, persistent:true
workspace = 6, monitor:HDMI-A-1
workspace = 7, monitor:HDMI-A-1
workspace = 8, monitor:HDMI-A-1

# Layout configuration
dwindle {
    pseudotile = true
    preserve_split = true
    force_split = 2
    no_gaps_when_only = false
}

master {
    new_is_master = true
    new_on_top = true
    mfact = 0.5
}
EOL
                ;;
            4)
                print_info "Configuring gestures and input..."
                # Configure input settings
                cat > ~/.config/hypr/input.conf <<EOL
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat
    force_no_accel = true
    
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
        disable_while_typing = true
    }
    
    gestures {
        workspace_swipe = true
        workspace_swipe_fingers = 3
        workspace_swipe_distance = 300
        workspace_swipe_invert = true
        workspace_swipe_min_speed_to_force = 30
    }
}
EOL
                ;;
            5)
                print_info "Configuring autostart applications..."
                # Configure autostart
                mkdir -p ~/.config/hypr/autostart
                cat > ~/.config/hypr/autostart.conf <<EOL
# Autostart applications
exec-once = waybar
exec-once = hyprpaper
exec-once = dunst
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = wl-clipboard-history -t
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = swayidle -w timeout 300 'swaylock -f' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = ~/.config/hypr/scripts/xdg-portal-hyprland
exec-once = /usr/lib/kdeconnectd
EOL
                ;;
            6)
                print_info "Configuring Waybar advanced..."
                
                # Backup existing configuration
                local timestamp=$(date +%Y%m%d_%H%M%S)
                if [ -d ~/.config/waybar ]; then
                    mv ~/.config/waybar ~/.config/waybar.backup_$timestamp
                fi
                
                mkdir -p ~/.config/waybar
                
                # Install additional modules
                yay -S --noconfirm \
                    waybar-module-pacman-updates-git \
                    waybar-module-weather-git
                
                # Create configuration
                cat > ~/.config/waybar/config <<EOL
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "margin-top": 6,
    "margin-bottom": 0,
    "margin-left": 6,
    "margin-right": 6,
    
    "modules-left": [
        "custom/launcher",
        "hyprland/workspaces",
        "hyprland/window"
    ],
    "modules-center": [
        "clock",
        "custom/weather"
    ],
    "modules-right": [
        "custom/updates",
        "pulseaudio",
        "network",
        "cpu",
        "memory",
        "temperature",
        "backlight",
        "battery",
        "tray"
    ],
    
    "custom/launcher": {
        "format": "",
        "on-click": "wofi --show drun",
        "tooltip": false
    },
    
    "custom/weather": {
        "format": "{}",
        "tooltip": true,
        "interval": 3600,
        "exec": "~/.config/waybar/scripts/weather.sh",
        "return-type": "json"
    },
    
    "custom/updates": {
        "format": " {}",
        "interval": 3600,
        "exec": "checkupdates | wc -l",
        "exec-if": "exit 0",
        "on-click": "alacritty -e sudo pacman -Syu",
        "signal": 8
    }
}
EOL
                
                # Validate configuration
                if ! validate_waybar_config; then
                    print_warning "Waybar configuration validation failed, restoring backup..."
                    rm -rf ~/.config/waybar
                    mv ~/.config/waybar.backup_$timestamp ~/.config/waybar
                    return 1
                fi
                
                print_success "Waybar configuration complete and validated"
                ;;
            7)
                print_info "Configuring window rules..."
                # Configure window rules
                cat > ~/.config/hypr/windowrules.conf <<EOL
# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$
windowrule = float, ^(nm-connection-editor)$
windowrule = float, ^(thunar)$
windowrule = float, title:^(Picture-in-Picture)$
windowrule = float, ^(swayimg)$
windowrule = opacity 0.92, ^(kitty)$
windowrule = workspace 2, ^(firefox)$
windowrule = workspace 3, ^(code)$
windowrule = workspace 4, ^(thunar)$
windowrule = workspace 5, ^(spotify)$
windowrule = idleinhibit focus, ^(mpv)$
windowrule = idleinhibit fullscreen, ^(firefox)$
EOL
                ;;
            8)
                print_info "Configuring keybindings..."
                # Configure keybindings
                cat > ~/.config/hypr/keybinds.conf <<EOL
# Basic bindings
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER SHIFT, Q, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,
bind = SUPER, F, fullscreen,
bind = SUPER, Space, exec, wofi --show drun
bind = SUPER, L, exec, swaylock

# Screenshot bindings
bind = , Print, exec, grimblast copy area
bind = SHIFT, Print, exec, grimblast save area
bind = CTRL, Print, exec, grimblast copy output
bind = CTRL SHIFT, Print, exec, grimblast save output

# Media controls
bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
bind = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

# Brightness controls
bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Window management
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

bind = SUPER SHIFT, left, movewindow, l
bind = SUPER SHIFT, right, movewindow, r
bind = SUPER SHIFT, up, movewindow, u
bind = SUPER SHIFT, down, movewindow, d

bind = SUPER CTRL, left, resizeactive, -20 0
bind = SUPER CTRL, right, resizeactive, 20 0
bind = SUPER CTRL, up, resizeactive, 0 -20
bind = SUPER CTRL, down, resizeactive, 0 20

# Workspace management
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8

bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8

# Special workspace
bind = SUPER, S, togglespecialworkspace,
bind = SUPER SHIFT, S, movetoworkspace, special

# Mouse bindings
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
EOL
                ;;
            9) break ;;
            *) print_error "Invalid choice" ;;
        esac
    done
}

# Validate Waybar configuration
validate_waybar_config() {
    print_header "Validating Waybar Configuration"
    local config_file="$HOME/.config/waybar/config"
    local style_file="$HOME/.config/waybar/style.css"
    local issues=0
    
    # Check if config files exist
    if [ ! -f "$config_file" ]; then
        print_error "Waybar config file not found"
        return 1
    fi
    
    if [ ! -f "$style_file" ]; then
        print_warning "Waybar style file not found"
        ((issues++))
    fi
    
    # Validate JSON syntax
    print_info "Validating JSON syntax..."
    if ! jq empty "$config_file" 2>/dev/null; then
        print_error "Invalid JSON in Waybar config"
        ((issues++))
    fi
    
    # Check required modules
    print_info "Checking required modules..."
    local required_modules=("clock" "cpu" "memory" "network" "pulseaudio" "tray")
    for module in "${required_modules[@]}"; do
        if ! grep -q "\"$module\"" "$config_file"; then
            print_warning "Missing required module: $module"
            ((issues++))
        fi
    done
    
    # Validate CSS syntax
    if [ -f "$style_file" ]; then
        print_info "Validating CSS syntax..."
        if ! stylelint "$style_file" 2>/dev/null; then
            print_warning "CSS validation failed"
            ((issues++))
        fi
    fi
    
    # Test Waybar configuration
    print_info "Testing Waybar configuration..."
    if ! waybar --validate 2>/dev/null; then
        print_error "Waybar configuration test failed"
        ((issues++))
    fi
    
    # Check custom scripts
    print_info "Checking custom scripts..."
    local scripts_dir="$HOME/.config/waybar/scripts"
    if [ -d "$scripts_dir" ]; then
        for script in "$scripts_dir"/*; do
            if [ -f "$script" ]; then
                if ! [ -x "$script" ]; then
                    print_warning "Script not executable: $script"
                    ((issues++))
                fi
            fi
        done
    fi
    
    # Summary
    if [ "$issues" -eq 0 ]; then
        print_success "Waybar configuration validation passed"
        return 0
    else
        print_warning "Waybar configuration validation found $issues issue(s)"
        return 1
    fi
}

# Source additional features
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/arch-toolbox-extras.sh"

# Update main menu function
show_main_menu() {
    while true; do
        print_header "Arch Linux Toolbox"
        echo -e "${CYAN}1${NC}) System Health Check"
        echo -e "${CYAN}2${NC}) Repair Hyprland"
        echo -e "${CYAN}3${NC}) Repair System"
        echo -e "${CYAN}4${NC}) Backup Configuration"
        echo -e "${CYAN}5${NC}) Restore Configuration"
        echo -e "${CYAN}6${NC}) Optimize System"
        echo -e "${CYAN}7${NC}) Performance Tuning"
        echo -e "${CYAN}8${NC}) AUR Management"
        echo -e "${CYAN}9${NC}) System Maintenance"
        echo -e "${CYAN}10${NC}) Security Hardening"
        echo -e "${CYAN}11${NC}) Gaming Optimization"
        echo -e "${CYAN}12${NC}) Restore Gaming Settings"
        echo -e "${CYAN}13${NC}) Development Environment"
        echo -e "${CYAN}14${NC}) Advanced Hyprland Customization"
        echo -e "${CYAN}15${NC}) System Integrity Check"
        echo -e "${CYAN}16${NC}) Restore System Optimizations"
        echo -e "${CYAN}17${NC}) Restore Security Settings"
        echo -e "${CYAN}18${NC}) Install Arch Linux (Dual-Boot)"
        echo -e "${CYAN}19${NC}) Manage Dotfiles"
        echo -e "${CYAN}20${NC}) View Logs"
        echo -e "${CYAN}21${NC}) Exit"
        echo
        read -rp "Enter your choice: " choice

        case $choice in
            1) check_system_health ;;
            2) repair_hyprland ;;
            3) repair_system ;;
            4) backup_config ;;
            5) restore_config ;;
            6) optimize_system ;;
            7) tune_performance ;;
            8) manage_aur ;;
            9) maintain_system ;;
            10) harden_system ;;
            11) 
                local gpu_type=$(detect_gpu)
                if validate_gpu_settings "$gpu_type"; then
                    optimize_gaming
                else
                    print_error "GPU validation failed. Please check your graphics drivers."
                fi
                ;;
            12) restore_gaming_optimizations ;;
            13) setup_dev_environment ;;
            14) customize_hyprland_advanced ;;
            15) verify_system_integrity ;;
            16) restore_system_optimizations ;;
            17) restore_security_settings ;;
            18) install_arch_dualboot ;;
            19) manage_dotfiles ;;
            20)
                echo -e "\n${CYAN}1${NC}) Installation Log"
                echo -e "${CYAN}2${NC}) Error Log"
                echo -e "${CYAN}3${NC}) Repair Log"
                echo -e "${CYAN}4${NC}) Debug Log"
                read -rp "Select log to view: " log_choice
                case $log_choice in
                    1) less "$INSTALL_LOG" ;;
                    2) less "$ERROR_LOG" ;;
                    3) less "$REPAIR_LOG" ;;
                    4) less "$DEBUG_LOG" ;;
                    *) print_error "Invalid choice" ;;
                esac
                ;;
            21) exit 0 ;;
            *) print_error "Invalid choice" ;;
        esac

        echo
        read -rp "Press Enter to continue..."
    done
}

# Check if running as root for certain operations
check_root() {
    if [ "$EUID" -ne 0 ]; then
        if [[ "$1" =~ ^(repair_system|optimize_system)$ ]]; then
            print_error "Please run as root for this operation"
            exit 1
        fi
    fi
}

# Main function
main() {
    # Setup logging
    setup_logging

    # Check system type
    if [ "$(detect_system_type)" != "arch" ]; then
        print_error "This script is intended for Arch Linux systems only"
        exit 1
    fi

    # Show main menu
    show_main_menu
}

# Run main function
main 