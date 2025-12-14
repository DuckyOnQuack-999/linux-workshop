#!/usr/bin/env bash

# Color and style definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m'

# Box drawing characters
TOP_LEFT="╭"
TOP_RIGHT="╮"
BOTTOM_LEFT="╰"
BOTTOM_RIGHT="╯"
HORIZONTAL="─"
VERTICAL="│"

# Icons
ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_ARROW="➜"
ICON_STAR="★"
ICON_WRENCH="🔧"
ICON_PACKAGE="📦"
ICON_GEAR="⚙️"
ICON_TERMINAL="💻"
ICON_CLOCK="🕒"
ICON_WARNING="⚠️"

# Script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
BACKUP_DIR="${SCRIPT_DIR}/backups"
LOG_FILE="${LOG_DIR}/super-rice-$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="${LOG_DIR}/error.log"

# Create necessary directories
mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"

# Logging functions
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR: $1${NC}" | tee -a "${ERROR_LOG}"
}

# Get terminal width
get_term_width() {
    tput cols 2>/dev/null || echo 80
}

# Create centered text
center_text() {
    local text="$1"
    local width=$(get_term_width)
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s%s%${padding}s\n" "" "$text" ""
}

# Create a box around text
box_text() {
    local text="$1"
    local width=$(get_term_width)
    local text_width=${#text}
    local padding=$(( (width - text_width - 4) / 2 ))
    local line=$(printf "%${padding}s" "" | tr " " "${HORIZONTAL}")
    
    echo -e "${CYAN}${TOP_LEFT}${line} ${text} ${line}${TOP_RIGHT}${NC}"
    echo -e "${CYAN}${BOTTOM_LEFT}$(printf "%${width}s" "" | tr " " "${HORIZONTAL}")${BOTTOM_RIGHT}${NC}"
}

# Enhanced progress indicator with percentage
show_progress() {
    local pid=$1
    local text=${2:-"Processing"}
    local width=$(get_term_width)
    local bar_size=40
    local delay=0.1
    local progress=0
    
    while ps -p $pid > /dev/null; do
        progress=$(( (progress + 1) % 100 ))
        filled=$(( progress * bar_size / 100 ))
        empty=$(( bar_size - filled ))
        
        printf "\r${CYAN}${ICON_CLOCK} ${text} [${GREEN}"
        printf "%${filled}s" "" | tr " " "▮"
        printf "${RED}%${empty}s${NC}] ${YELLOW}%3d%%${NC}" "" "$progress"
        sleep $delay
    done
    printf "\r${GREEN}${ICON_CHECK} ${text} Complete!${NC}%$((width-${#text}-20))s\n" ""
}

# Check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Dependency check
check_dependencies() {
    # Define core base-devel components to check
    local base_devel_deps=("gcc" "make" "autoconf" "automake" "binutils" "libtool")
    local binary_deps=("git" "curl" "wget" "jq" "yay" "paru" "cmake" "python" "pip" "rust" "go")

    # Check binary dependencies using command -v
    for dep in "${binary_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' is not installed"
            return 1
        fi
    done

    # Check base-devel components using pacman
    for dep in "${base_devel_deps[@]}"; do
        if ! pacman -Qi "$dep" &> /dev/null; then
            log_error "Required base-devel component '$dep' is not installed"
            return 1
        fi
    done

    return 0
}

# Backup function
create_backup() {
    local backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/config_backup_${backup_date}.tar.gz"
    
    log "Creating backup of current configurations..."
    tar -czf "${backup_file}" \
        ~/.config/hypr \
        ~/.config/waybar \
        ~/.config/wofi \
        ~/.config/mako \
        ~/.config/dunst \
        2>/dev/null || true
    
    if [[ -f "${backup_file}" ]]; then
        log "Backup created successfully at ${backup_file}"
    else
        log_error "Backup creation failed"
    fi
}

# System update function
system_update() {
    log "Starting system update..."
    
    # Update system packages
    log "Updating system packages..."
    pacman -Syu --noconfirm &
    show_progress $!
    
    # Update AUR packages
    log "Updating AUR packages..."
    yay -Sua --noconfirm &
    show_progress $!
    
    # Clean package cache
    log "Cleaning package cache..."
    paccache -r &
    show_progress $!
    
    log "System update completed successfully"
}

# Hyprland installation function
install_hyprland() {
    log "Starting Hyprland installation..."
    
    # Install base packages
    local packages=(
        # Base Hyprland
        hyprland
        waybar
        wofi
        mako
        dunst
        kitty
        polkit-kde-agent
        xdg-desktop-portal-hyprland
        
        # System utilities
        btop
        neofetch
        ranger
        zsh
        oh-my-zsh-git
        starship
        
        # Audio
        pipewire
        pipewire-pulse
        pavucontrol
        
        # Network
        networkmanager
        network-manager-applet
        
        # File management
        thunar
        thunar-archive-plugin
        file-roller
        
        # Theme and appearance
        qt5ct
        qt6ct
        kvantum
        nwg-look-bin
        
        # Screenshot and recording
        grim
        slurp
        wf-recorder
        
        # System tray
        blueman
        nm-applet
        
        # Security
        polkit-gnome
    )
    
    for pkg in "${packages[@]}"; do
        log "Installing ${pkg}..."
        yay -S --noconfirm "$pkg" &
        show_progress $!
    done
    
    # Configure Hyprland
    log "Configuring Hyprland..."
    mkdir -p ~/.config/hypr
    
    # Copy configuration files
    cp -r "${SCRIPT_DIR}/config/hypr/"* ~/.config/hypr/ &>/dev/null || log_error "Failed to copy Hyprland configs"
    
    log "Hyprland installation completed"
}

# Advanced Hyprland configuration
configure_hyprland_advanced() {
    log "Applying advanced Hyprland configurations..."
    
    # Install additional packages
    local adv_packages=(
        # Display and graphics
        wlsunset
        waybar-hyprland
        swaylock-effects
        wl-clipboard
        slurp
        grim
        hyprpicker
        wev
        xdg-desktop-portal-wlr
        
        # Multimedia
        mpv
        imv
        ffmpeg
        
        # Communication
        discord
        telegram-desktop
        
        # Development
        git
        github-cli
        visual-studio-code-bin
        vim
        neovim
        
        # Terminal improvements
        alacritty
        tmux
        zoxide
        fzf
        bat
        exa
        
        # System monitoring
        btop
        htop
        powertop
        
        # File synchronization
        syncthing
        rclone
    )
    
    for pkg in "${adv_packages[@]}"; do
        log "Installing ${pkg}..."
        yay -S --noconfirm "$pkg" &
        show_progress $!
    done
    
    # Configure advanced features
    mkdir -p ~/.config/waybar
    mkdir -p ~/.config/swaylock
    
    # Copy advanced configurations
    cp -r "${SCRIPT_DIR}/config/advanced/"* ~/.config/ &>/dev/null || log_error "Failed to copy advanced configs"
    
    log "Advanced configuration completed"
}

# Productivity tools installation
install_productivity_tools() {
    log "Installing productivity tools..."
    
    local prod_packages=(
        # Productivity
        obsidian
        notion-app
        visual-studio-code-bin
        thunderbird
        libreoffice-fresh
        
        # Writing and notes
        marktext
        typora
        zettlr
        
        # Task management
        todoist
        planner
        
        # Communication
        zoom
        teams
        slack-desktop
        
        # Development
        postman
        insomnia
        dbeaver
        
        # Graphics and design
        gimp
        inkscape
        krita
        
        # PDF tools
        okular
        zathura
        
        # Cloud storage
        dropbox
        nextcloud-client
    )
    
    for pkg in "${prod_packages[@]}"; do
        log "Installing ${pkg}..."
        yay -S --noconfirm "$pkg" &
        show_progress $!
    done
    
    log "Productivity tools installation completed"
}

# Show fancy header
show_header() {
    clear
    center_text "${CYAN}╭─────────────────────────────────────────────────╮${NC}"
    center_text "${CYAN}│${BOLD}${WHITE}           🚀 SUPER RICE SCRIPT v2.0           ${NC}${CYAN}│${NC}"
    center_text "${CYAN}│${YELLOW}      Your Ultimate System Configuration Tool     ${NC}${CYAN}│${NC}"
    center_text "${CYAN}╰─────────────────────────────────────────────────╯${NC}"
    echo
}

# Show system stats
show_system_stats() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    local mem_usage=$(free -m | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
    local disk_usage=$(df -h / | awk '/\// {print $(NF-1)}' | tr -d '%')
    
    echo -e "${CYAN}${VERTICAL} System Stats ${VERTICAL}${NC}"
    echo -e "${GREEN}CPU: ${cpu_usage}% │ RAM: ${mem_usage}% │ Disk: ${disk_usage}%${NC}"
    echo
}

# Menu system
show_menu() {
    show_header
    show_system_stats
    
    box_text "System Management"
    echo -e "${ICON_WRENCH} ${YELLOW}1)${NC} System Update"
    echo -e "${ICON_PACKAGE} ${YELLOW}2)${NC} System Backup/Restore"
    echo -e "${ICON_GEAR} ${YELLOW}3)${NC} System Optimization"
    echo -e "${ICON_TERMINAL} ${YELLOW}4)${NC} Security Hardening"
    echo
    echo -e "${YELLOW}1) System Update${NC}"
    echo -e "${YELLOW}2) System Backup/Restore${NC}"
    echo -e "${YELLOW}3) System Optimization${NC}"
    echo -e "${YELLOW}4) Security Hardening${NC}"
    
    echo -e "\n${YELLOW}=== Desktop Environment ===${NC}"
    echo -e "${YELLOW}5) Install/Configure Hyprland${NC}"
    echo -e "${YELLOW}6) Install Advanced Hyprland Features${NC}"
    echo -e "${YELLOW}7) Install Additional Desktop Environments${NC}"
    echo -e "${YELLOW}8) Configure Themes and Appearance${NC}"
    
    echo -e "\n${YELLOW}=== Software ===${NC}"
    echo -e "${YELLOW}9) Install Productivity Tools${NC}"
    echo -e "${YELLOW}10) Install Development Tools${NC}"
    echo -e "${YELLOW}11) Install Media Tools${NC}"
    echo -e "${YELLOW}12) Install Gaming Tools${NC}"
    echo -e "${YELLOW}13) Install Virtualization Tools${NC}"
    
    echo -e "\n${YELLOW}=== Advanced ===${NC}"
    echo -e "${YELLOW}14) Configure Network Optimization${NC}"
    echo -e "${YELLOW}15) Configure Power Management${NC}"
    echo -e "${YELLOW}16) Do Everything${NC}"
    echo -e "${YELLOW}0) Exit${NC}"
    
    read -p "Enter your choice: " choice
    
    case $choice in
        1) system_update ;;
        2) backup_menu ;;
        3) system_optimization ;;
        4) security_hardening ;;
        5) install_hyprland ;;
        6) configure_hyprland_advanced ;;
        7) install_desktop_environments ;;
        8) configure_themes ;;
        9) install_productivity_tools ;;
        10) install_dev_tools ;;
        11) install_media_tools ;;
        12) install_gaming_tools ;;
        13) install_virtualization ;;
        14) configure_network ;;
        15) configure_power ;;
        16)
            create_backup
            system_update
            system_optimization
            security_hardening
            install_hyprland
            configure_hyprland_advanced
            install_productivity_tools
            install_dev_tools
            install_media_tools
            install_gaming_tools
            install_virtualization
            configure_network
            configure_power
            configure_themes
            ;;
        0) exit 0 ;;
        *) log_error "Invalid choice" ;;
    esac
}

# Main execution
main() {
    # Check requirements
    check_root
    check_dependencies || exit 1
    
    # Show menu
    while true; do
        show_menu
    done
}

# Start script
main

