#!/bin/bash

# Arch Linux Installation Script with Hyprland
# Author: duckyonquack999
# License: MIT
# Description: Automated Arch Linux installation with Hyprland desktop environment

# Set strict error handling
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Icons
CHECK_ICON="✓"
ERROR_ICON="✗"
INFO_ICON="ℹ"
WARN_ICON="⚠"

# Functions for printing messages
print_info() {
    log_info "$1"
    echo -e "${BLUE}${INFO_ICON} $1${NC}"
}

print_success() {
    log_info "[SUCCESS] $1"
    echo -e "${GREEN}${CHECK_ICON} $1${NC}"
}

print_error() {
    log_error "$1"
    echo -e "${RED}${ERROR_ICON} $1${NC}"
}

print_warning() {
    log_info "[WARNING] $1"
    echo -e "${YELLOW}${WARN_ICON} $1${NC}"
}

# Logging configuration
LOG_DIR="/var/log/arch-install"
INSTALL_LOG="${LOG_DIR}/install.log"
ERROR_LOG="${LOG_DIR}/error.log"
DEBUG_LOG="${LOG_DIR}/debug.log"

# Initialize logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    touch "$INSTALL_LOG" "$ERROR_LOG" "$DEBUG_LOG"
    
    # Redirect stdout and stderr to both console and log files
    exec 1> >(tee -a "$INSTALL_LOG")
    exec 2> >(tee -a "$ERROR_LOG")
}

# Enhanced logging functions
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [INFO] $1" | tee -a "$INSTALL_LOG"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [ERROR] $1" | tee -a "$ERROR_LOG"
}

log_debug() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [DEBUG] $1" | tee -a "$DEBUG_LOG"
}

# Function to display logs
show_logs() {
    local log_type=$1
    case $log_type in
        "install") less "$INSTALL_LOG" ;;
        "error") less "$ERROR_LOG" ;;
        "debug") less "$DEBUG_LOG" ;;
        *) echo "Invalid log type. Use: install, error, or debug" ;;
    esac
}

# Function to check if running in UEFI mode
check_uefi() {
    if [ -d "/sys/firmware/efi/efivars" ]; then
        print_success "UEFI mode detected"
        return 0
    else
        print_error "UEFI mode not detected. This script requires UEFI boot mode."
        exit 1
    fi
}

# Function to check internet connection
check_internet() {
    if ping -c 1 archlinux.org >/dev/null 2>&1; then
        print_success "Internet connection detected"
    else
        print_error "No internet connection available"
        exit 1
    fi
}

# Function to update system clock
update_clock() {
    print_info "Updating system clock..."
    timedatectl set-ntp true
    print_success "System clock updated"
}

# Function to prepare disk
prepare_disk() {
    print_info "Available disks:"
    lsblk
    read -rp "Enter the disk to install Arch Linux (e.g., /dev/sda): " disk
    
    print_warning "This will erase all data on $disk. Are you sure? (y/N)"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Installation aborted"
        exit 1
    fi
    
    # Create partitions
    print_info "Creating partitions..."
    parted -s "$disk" mklabel gpt
    parted -s "$disk" mkpart primary fat32 1MiB 513MiB
    parted -s "$disk" set 1 esp on
    parted -s "$disk" mkpart primary linux-swap 513MiB 4609MiB
    parted -s "$disk" mkpart primary ext4 4609MiB 100%
    
    # Format partitions
    print_info "Formatting partitions..."
    mkfs.fat -F32 "${disk}1"
    mkswap "${disk}2"
    mkfs.ext4 "${disk}3"
    
    # Mount partitions
    print_info "Mounting partitions..."
    mount "${disk}3" /mnt
    mkdir -p /mnt/boot/efi
    mount "${disk}1" /mnt/boot/efi
    swapon "${disk}2"
    
    print_success "Disk preparation completed"
}

# Function to install base system
install_base() {
    print_info "Installing base system..."
    
    pacstrap /mnt base base-devel linux linux-firmware
    
    # Generate fstab
    print_info "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Create initial backup
    create_system_backup
    
    print_success "Base system installed"
}

# Function to configure system
configure_system() {
    print_info "Configuring system..."
    
    # Chroot and configure
    arch-chroot /mnt /bin/bash <<EOF
    # Set timezone
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    
    # Set locale
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    
    # Set hostname
    echo "archlinux" > /etc/hostname
    
    # Set root password
    echo "Set root password:"
    passwd
    
    # Create user
    useradd -m -G wheel -s /bin/bash user
    echo "Set user password:"
    passwd user
    
    # Configure sudo
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
    
    # Install and configure bootloader
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
EOF
    
    print_success "System configuration completed"
}

# Function to install Hyprland and dependencies
install_hyprland() {
    print_info "Installing Hyprland and dependencies..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Install required packages
    pacman -S --noconfirm \
        hyprland \
        waybar \
        kitty \
        wofi \
        light \
        networkmanager \
        network-manager-applet \
        pulseaudio \
        pulseaudio-alsa \
        pavucontrol \
        brightnessctl \
        grim \
        slurp \
        wl-clipboard \
        mako \
        xdg-desktop-portal-hyprland \
        qt5-wayland \
        qt6-wayland \
        polkit-gnome \
        gnome-keyring \
        thunar \
        firefox
    
    # Enable services
    systemctl enable NetworkManager
    systemctl enable bluetooth
    
    # Create Hyprland config directory
    mkdir -p /home/user/.config/hypr
    
    # Create basic Hyprland config
    cat > /home/user/.config/hypr/hyprland.conf <<EEOF
# Monitor configuration
monitor=,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = mako
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# General settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Decoration settings
decoration {
    rounding = 10
    blur = true
    blur_size = 3
    blur_passes = 1
    blur_new_optimizations = true
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
}

# Animation settings
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$
windowrule = float, ^(nm-connection-editor)$

# Key bindings
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, P, pseudo,
bind = SUPER, F, fullscreen,

# Move focus
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

# Switch workspaces
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9
bind = SUPER, 0, workspace, 10

# Move active window to workspace
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9
bind = SUPER SHIFT, 0, movetoworkspace, 10

# Mouse bindings
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
EEOF

    # Set permissions
    chown -R user:user /home/user/.config
EOF
    
    print_success "Hyprland installation completed"
}

# Function to detect and install GPU drivers
install_gpu_drivers() {
    print_info "Detecting GPU..."
    
    arch-chroot /mnt /bin/bash <<EOF
    if lspci | grep -i "nvidia" >/dev/null; then
        print_info "NVIDIA GPU detected"
        pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
        # Enable DRM kernel mode setting
        sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
        mkinitcpio -P
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    
    if lspci | grep -i "amd" >/dev/null; then
        print_info "AMD GPU detected"
        pacman -S --noconfirm xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
    fi
    
    if lspci | grep -i "intel" >/dev/null; then
        print_info "Intel GPU detected"
        pacman -S --noconfirm xf86-video-intel mesa lib32-mesa vulkan-intel lib32-vulkan-intel
    fi
EOF
}

# Function to install additional software
install_additional_software() {
    print_info "Installing additional software..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Development tools
    pacman -S --noconfirm \
        git \
        base-devel \
        cmake \
        python \
        python-pip \
        nodejs \
        npm \
        docker
    
    # System utilities
    pacman -S --noconfirm \
        htop \
        neofetch \
        ranger \
        fzf \
        ripgrep \
        bat \
        exa \
        zsh \
        starship
    
    # Multimedia
    pacman -S --noconfirm \
        mpv \
        imv \
        gimp \
        obs-studio \
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        pipewire-jack
    
    # Security
    pacman -S --noconfirm \
        ufw \
        fail2ban \
        firejail \
        arch-audit
    
    # Enable services
    systemctl enable docker
    systemctl enable ufw
    systemctl enable fail2ban
    
    # Configure zsh
    chsh -s /bin/zsh user
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sudo -u user sh
    
    # Configure firewall
    ufw default deny incoming
    ufw default allow outgoing
    ufw enable
EOF
}

# Function to optimize system
optimize_system() {
    print_info "Optimizing system..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Performance tweaks
    echo "vm.swappiness=10" > /etc/sysctl.d/99-sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.d/99-sysctl.conf
    
    # Enable periodic TRIM
    systemctl enable fstrim.timer
    
    # Configure makepkg for parallel compilation
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
    
    # Configure pacman
    sed -i 's/#Color/Color/' /etc/pacman.conf
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
    
    # Install and configure thermald for better thermal management
    pacman -S --noconfirm thermald
    systemctl enable thermald
    
    # Install and configure earlyoom to prevent system freezes
    pacman -S --noconfirm earlyoom
    systemctl enable earlyoom
    
    # Configure systemd-oomd
    systemctl enable systemd-oomd
    
    # Install and configure irqbalance for better CPU interrupt handling
    pacman -S --noconfirm irqbalance
    systemctl enable irqbalance
    
    # Install and configure preload for faster application startup
    pacman -S --noconfirm preload
    systemctl enable preload
EOF
}

# Function to configure desktop environment
configure_desktop() {
    print_info "Configuring desktop environment..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Install themes and icons
    pacman -S --noconfirm \
        papirus-icon-theme \
        arc-gtk-theme \
        arc-icon-theme \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        ttf-jetbrains-mono-nerd \
        ttf-font-awesome
    
    # Create Waybar config directory
    mkdir -p /home/user/.config/waybar
    
    # Create Waybar config
    cat > /home/user/.config/waybar/config <<EEOF
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "battery", "tray"],
    
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },
    
    "hyprland/window": {
        "format": "{}",
        "max-length": 50
    },
    
    "clock": {
        "format": "{:%Y-%m-%d %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "cpu": {
        "format": " {usage}%",
        "tooltip": false
    },
    
    "memory": {
        "format": " {}%"
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    
    "network": {
        "format-wifi": " {essid} ({signalStrength}%)",
        "format-ethernet": " {ipaddr}/{cidr}",
        "tooltip-format": " {ifname} via {gwaddr}",
        "format-linked": " {ifname} (No IP)",
        "format-disconnected": "⚠ Disconnected",
        "format-alt": "{ifname}: {ipaddr}/{cidr}"
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-bluetooth": "{icon} {volume}% ",
        "format-bluetooth-muted": " {icon} ",
        "format-muted": " ",
        "format-icons": {
            "headphone": "",
            "hands-free": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": "",
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    
    "tray": {
        "icon-size": 21,
        "spacing": 10
    }
}
EEOF
    
    # Create Waybar style
    cat > /home/user/.config/waybar/style.css <<EEOF
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono Nerd Font";
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: rgba(43, 48, 59, 0.5);
    border-bottom: 3px solid rgba(100, 114, 125, 0.5);
    color: #ffffff;
    transition-property: background-color;
    transition-duration: .5s;
}

window#waybar.hidden {
    opacity: 0.2;
}

#workspaces button {
    padding: 0 5px;
    background-color: transparent;
    color: #ffffff;
    border-bottom: 3px solid transparent;
}

#workspaces button:hover {
    background: rgba(0, 0, 0, 0.2);
    box-shadow: inherit;
    border-bottom: 3px solid #ffffff;
}

#workspaces button.active {
    background-color: #64727D;
    border-bottom: 3px solid #ffffff;
}

#clock,
#battery,
#cpu,
#memory,
#network,
#pulseaudio,
#tray {
    padding: 0 10px;
    margin: 0 4px;
    color: #ffffff;
}

#clock {
    background-color: #64727D;
}

#battery {
    background-color: #ffffff;
    color: #000000;
}

#battery.charging {
    color: #ffffff;
    background-color: #26A65B;
}

#battery.warning:not(.charging) {
    background-color: #ffbe61;
    color: black;
}

#battery.critical:not(.charging) {
    background-color: #f53c3c;
    color: #ffffff;
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#cpu {
    background-color: #2ecc71;
    color: #000000;
}

#memory {
    background-color: #9b59b6;
}

#network {
    background-color: #2980b9;
}

#network.disconnected {
    background-color: #f53c3c;
}

#pulseaudio {
    background-color: #f1c40f;
    color: #000000;
}

#pulseaudio.muted {
    background-color: #90b1b1;
    color: #2a5c45;
}

#tray {
    background-color: #2980b9;
}
EEOF
    
    # Download and set wallpaper
    mkdir -p /home/user/.local/share/wallpapers
    curl -L https://raw.githubusercontent.com/hyprwm/hyprland-rs/main/assets/wallpaper.png -o /home/user/.local/share/wallpapers/default.png
    
    # Add wallpaper to Hyprland config
    echo "exec-once = swaybg -i ~/.local/share/wallpapers/default.png -m fill" >> /home/user/.config/hypr/hyprland.conf
    
    # Configure GTK theme
    mkdir -p /home/user/.config/gtk-3.0
    cat > /home/user/.config/gtk-3.0/settings.ini <<EEOF
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EEOF
    
    # Set permissions
    chown -R user:user /home/user/.config
    chown -R user:user /home/user/.local
EOF
}

# Function to install AUR helper
install_aur_helper() {
    print_info "Installing AUR helper (yay)..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Install git (required for yay)
    pacman -S --noconfirm git base-devel
    
    # Create build user for AUR packages
    useradd -m -G wheel builder
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
    
    # Switch to builder user and install yay
    su - builder -c "git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"
    
    # Clean up
    userdel -r builder
    rm /etc/sudoers.d/builder
    
    # Install some useful AUR packages
    su - user -c "yay -S --noconfirm \
        hyprland-git \
        waybar-hyprland-git \
        catppuccin-gtk-theme \
        bibata-cursor-theme \
        nwg-look \
        swaylock-effects \
        wlogout \
        hyprpicker \
        hyprpaper"
EOF
}

# Function to configure shell environment
configure_shell() {
    print_info "Configuring shell environment..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Install zsh plugins
    su - user -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions'
    su - user -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting'
    
    # Configure zsh
    cat > /home/user/.zshrc <<EEOF
# Oh My Zsh configuration
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh

# Environment variables
export EDITOR="nvim"
export TERMINAL="kitty"
export BROWSER="firefox"
export PATH="\$HOME/.local/bin:\$PATH"

# Aliases
alias ls='exa --icons'
alias ll='exa -l --icons'
alias la='exa -la --icons'
alias cat='bat'
alias vim='nvim'
alias update='yay -Syu'
alias cleanup='yay -Yc'

# Starship prompt
eval "\$(starship init zsh)"
EEOF
    
    # Configure Starship prompt
    mkdir -p /home/user/.config
    cat > /home/user/.config/starship.toml <<EEOF
# Starship prompt configuration

[character]
success_symbol = "[➜](bold green) "
error_symbol = "[✗](bold red) "

[cmd_duration]
min_time = 500
format = "took [$duration](bold yellow)"

[directory]
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = " "
truncation_length = 4
truncation_symbol = ""

[git_status]
conflicted = "🏳"
ahead = "🏎💨"
behind = "😰"
diverged = "😵"
untracked = "🤷"
stashed = "📦"
modified = "📝"
staged = '[++\($count\)](green)'
renamed = "👅"
deleted = "🗑"

[nodejs]
symbol = " "

[package]
symbol = " "

[python]
symbol = " "

[rust]
symbol = " "
EEOF
    
    # Set permissions
    chown -R user:user /home/user/.zshrc
    chown -R user:user /home/user/.config/starship.toml
EOF
}

# Function to configure development environment
configure_dev_environment() {
    print_info "Configuring development environment..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Install development tools
    pacman -S --noconfirm \
        neovim \
        tmux \
        git-delta \
        lazygit \
        shellcheck \
        ctags \
        docker \
        docker-compose \
        visual-studio-code-bin
    
    # Configure Neovim
    su - user -c 'git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1'
    
    # Configure tmux
    cat > /home/user/.tmux.conf <<EEOF
# Enable mouse support
set -g mouse on

# Set prefix to Ctrl+Space
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Enable true color support
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Set status bar
set -g status-style 'bg=#333333 fg=#5eacd3'
set -g status-position top

# Vim-like pane switching
bind -r k select-pane -U
bind -r j select-pane -D
bind -r h select-pane -L
bind -r l select-pane -R
EEOF
    
    # Configure Git
    su - user -c 'git config --global core.pager "delta"'
    su - user -c 'git config --global interactive.diffFilter "delta --color-only"'
    su - user -c 'git config --global delta.navigate true'
    su - user -c 'git config --global delta.light false'
    su - user -c 'git config --global merge.conflictstyle diff3'
    su - user -c 'git config --global diff.colorMoved default'
    
    # Enable Docker service
    systemctl enable docker
    usermod -aG docker user
    
    # Set permissions
    chown -R user:user /home/user/.tmux.conf
EOF
}

# Function to add additional Hyprland customizations
customize_hyprland() {
    print_info "Adding additional Hyprland customizations..."
    
    arch-chroot /mnt /bin/bash <<EOF
    # Install additional tools
    pacman -S --noconfirm \
        swayidle \
        playerctl \
        brightnessctl \
        pamixer \
        imagemagick \
        jq
    
    # Configure swaylock
    mkdir -p /home/user/.config/swaylock
    cat > /home/user/.config/swaylock/config <<EEOF
ignore-empty-password
font=Noto Sans

clock
timestr=%R
datestr=%a, %e of %B

screenshots

fade-in=0.2

effect-blur=20x2
effect-scale=0.3

indicator
indicator-radius=240
indicator-thickness=20
indicator-caps-lock

key-hl-color=880033

separator-color=00000000

inside-color=00000099
inside-clear-color=ffd20400
inside-caps-lock-color=009ddc00
inside-ver-color=d9d8d800
inside-wrong-color=ee2e2400

ring-color=231f20D9
ring-clear-color=231f20D9
ring-caps-lock-color=231f20D9
ring-ver-color=231f20D9
ring-wrong-color=231f20D9

line-color=00000000
line-clear-color=ffd204FF
line-caps-lock-color=009ddcFF
line-ver-color=d9d8d8FF
line-wrong-color=ee2e24FF

text-clear-color=ffd20400
text-ver-color=d9d8d800
text-wrong-color=ee2e2400

bs-hl-color=ee2e24FF
caps-lock-key-hl-color=ffd204FF
caps-lock-bs-hl-color=ee2e24FF
disable-caps-lock-text
text-caps-lock-color=009ddc
EEOF
    
    # Configure wlogout
    mkdir -p /home/user/.config/wlogout
    cat > /home/user/.config/wlogout/style.css <<EEOF
* {
    background-image: none;
    font-family: "JetBrains Mono Nerd Font";
}

window {
    background-color: rgba(12, 12, 12, 0.9);
}

button {
    color: #FFFFFF;
    background-color: #1E1E1E;
    border-style: solid;
    border-width: 2px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
}

button:focus, button:active, button:hover {
    background-color: #3700B3;
    outline-style: none;
}

#lock {
    background-image: image(url("/usr/share/wlogout/icons/lock.png"), url("/usr/local/share/wlogout/icons/lock.png"));
}

#logout {
    background-image: image(url("/usr/share/wlogout/icons/logout.png"), url("/usr/local/share/wlogout/icons/logout.png"));
}

#suspend {
    background-image: image(url("/usr/share/wlogout/icons/suspend.png"), url("/usr/local/share/wlogout/icons/suspend.png"));
}

#hibernate {
    background-image: image(url("/usr/share/wlogout/icons/hibernate.png"), url("/usr/local/share/wlogout/icons/hibernate.png"));
}

#shutdown {
    background-image: image(url("/usr/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png"));
}

#reboot {
    background-image: image(url("/usr/share/wlogout/icons/reboot.png"), url("/usr/local/share/wlogout/icons/reboot.png"));
}
EEOF
    
    # Add additional keybindings to Hyprland config
    cat >> /home/user/.config/hypr/hyprland.conf <<EEOF
# Additional keybindings
bind = SUPER, L, exec, swaylock
bind = SUPER SHIFT, E, exec, wlogout
bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
bind = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous
bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Window rules
windowrule = float, ^(wlogout)$
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$
windowrule = float, ^(nm-connection-editor)$
windowrule = float, ^(thunar)$
windowrule = float, title:^(btop)$
windowrule = float, title:^(update-sys)$

# Animation settings
animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Misc settings
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    mouse_move_enables_dpms = true
    no_vfr = false
}
EEOF
    
    # Set permissions
    chown -R user:user /home/user/.config
EOF
}

# Function to create system backup
create_system_backup() {
    print_info "Creating system backup..."
    
    local backup_dir="/mnt/var/backups/system"
    local date_stamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="system_backup_${date_stamp}.tar.gz"
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Create list of installed packages
    arch-chroot /mnt /bin/bash -c "pacman -Qqe > /var/backups/system/pkg_list_${date_stamp}.txt"
    
    # Backup important directories
    tar -czf "${backup_dir}/${backup_file}" \
        -C /mnt/etc . \
        -C /mnt/home . \
        -C /mnt/root . \
        -C /mnt/var/lib/pacman/local . \
        --exclude='*/tmp/*' \
        --exclude='*/cache/*' \
        --exclude='*/log/*'
    
    print_success "System backup created at ${backup_dir}/${backup_file}"
}

# Function to restore system from backup
restore_system() {
    print_info "Available system backups:"
    ls -lh /var/backups/system/
    
    read -rp "Enter backup file to restore from: " backup_file
    
    if [ ! -f "/var/backups/system/${backup_file}" ]; then
        print_error "Backup file not found"
        return 1
    fi
    
    print_warning "This will overwrite current system files. Continue? [y/N]"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_info "Restore cancelled"
        return 0
    fi
    
    # Extract backup
    tar -xzf "/var/backups/system/${backup_file}" -C /
    
    # Reinstall packages
    local date_stamp=$(echo "$backup_file" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    if [ -f "/var/backups/system/pkg_list_${date_stamp}.txt" ]; then
        pacman -S --needed - < "/var/backups/system/pkg_list_${date_stamp}.txt"
    fi
    
    print_success "System restored from backup"
}

# Function to verify system integrity
verify_system() {
    print_info "Verifying system integrity..."
    local errors=0
    
    # Check filesystem
    print_info "Checking filesystems..."
    if ! arch-chroot /mnt /bin/bash -c "fsck -A -T"; then
        print_error "Filesystem errors detected"
        ((errors++))
    fi
    
    # Verify package integrity
    print_info "Verifying installed packages..."
    if ! arch-chroot /mnt /bin/bash -c "pacman -Qk"; then
        print_error "Package integrity errors detected"
        ((errors++))
    fi
    
    # Check for broken symlinks
    print_info "Checking for broken symlinks..."
    if arch-chroot /mnt /bin/bash -c "find / -xtype l -print" | grep -q .; then
        print_warning "Broken symlinks found"
        ((errors++))
    fi
    
    # Check disk space
    print_info "Checking disk space..."
    if arch-chroot /mnt /bin/bash -c "df -h / /boot/efi" | awk 'NR>1 {gsub(/%/,"",$5); if($5 > 90) exit 1}'; then
        print_warning "Low disk space detected"
        ((errors++))
    fi
    
    # Verify bootloader
    print_info "Checking bootloader..."
    if ! arch-chroot /mnt /bin/bash -c "grub-script-check /boot/grub/grub.cfg"; then
        print_error "GRUB configuration errors detected"
        ((errors++))
    fi
    
    return $errors
}

# Function to repair system
repair_system() {
    print_info "Starting system repair..."
    
    # Repair filesystem
    print_info "Repairing filesystems..."
    arch-chroot /mnt /bin/bash -c "fsck -y -A -T"
    
    # Reinstall corrupted packages
    print_info "Repairing package integrity..."
    arch-chroot /mnt /bin/bash -c "pacman -Qk | grep 'missing' | awk '{print \$1}' | xargs -r pacman -S --noconfirm"
    
    # Clean package cache
    print_info "Cleaning package cache..."
    arch-chroot /mnt /bin/bash -c "paccache -r"
    
    # Rebuild initramfs
    print_info "Rebuilding initramfs..."
    arch-chroot /mnt /bin/bash -c "mkinitcpio -P"
    
    # Rebuild GRUB config
    print_info "Rebuilding GRUB configuration..."
    arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    
    print_success "System repair completed"
}

# Progress tracking variables
declare -A STEPS_STATUS
STEPS=(
    "check_uefi"
    "check_internet"
    "update_clock"
    "prepare_disk"
    "install_base"
    "configure_system"
    "install_gpu_drivers"
    "install_hyprland"
    "install_additional_software"
    "optimize_system"
    "configure_desktop"
    "install_aur_helper"
    "configure_shell"
    "configure_dev_environment"
    "customize_hyprland"
)

# Function to show progress
show_progress() {
    clear
    print_info "Arch Linux Installation Progress:"
    echo
    for step in "${STEPS[@]}"; do
        status="${STEPS_STATUS[$step]:-Pending}"
        case $status in
            "Done") echo -e "${GREEN}[✓]${NC} ${step//_/ }" ;;
            "Failed") echo -e "${RED}[✗]${NC} ${step//_/ }" ;;
            "In Progress") echo -e "${YELLOW}[⋯]${NC} ${step//_/ }" ;;
            *) echo -e "${BLUE}[ ]${NC} ${step//_/ }" ;;
        esac
    done
    echo
}

# Function to update step status
update_step() {
    local step=$1
    local status=$2
    STEPS_STATUS[$step]=$status
    show_progress
}

# Function to get user configuration
get_user_config() {
    print_info "Welcome to Arch Linux Installer with Hyprland"
    echo
    print_info "Please configure your installation:"
    echo
    
    # Hostname
    read -rp "Enter hostname [archlinux]: " hostname
    hostname=${hostname:-archlinux}
    
    # Username
    read -rp "Enter username [user]: " username
    username=${username:-user}
    
    # Timezone
    echo
    print_info "Available timezones:"
    timedatectl list-timezones | grep -E "America|Europe|Asia" | less
    read -rp "Enter timezone [UTC]: " timezone
    timezone=${timezone:-UTC}
    
    # Locale
    read -rp "Enter locale [en_US.UTF-8]: " locale
    locale=${locale:-en_US.UTF-8}
    
    # Keyboard layout
    read -rp "Enter keyboard layout [us]: " keyboard
    keyboard=${keyboard:-us}
    
    # Desktop configuration
    echo
    print_info "Desktop Configuration:"
    read -rp "Install development tools? [Y/n]: " install_dev
    install_dev=${install_dev:-Y}
    
    read -rp "Install multimedia tools? [Y/n]: " install_multimedia
    install_multimedia=${install_multimedia:-Y}
    
    read -rp "Install gaming tools? [Y/n]: " install_gaming
    install_gaming=${install_gaming:-Y}
    
    # Confirm configuration
    echo
    print_info "Installation Configuration:"
    echo "Hostname: $hostname"
    echo "Username: $username"
    echo "Timezone: $timezone"
    echo "Locale: $locale"
    echo "Keyboard: $keyboard"
    echo "Install development tools: $install_dev"
    echo "Install multimedia tools: $install_multimedia"
    echo "Install gaming tools: $install_gaming"
    echo
    
    read -rp "Proceed with installation? [Y/n]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]] && [[ -n $confirm ]]; then
        print_error "Installation cancelled"
        exit 1
    fi
}

# Function to perform post-installation checks
post_install_checks() {
    print_info "Performing post-installation checks..."
    
    local errors=0
    
    # Check if system is bootable
    if ! arch-chroot /mnt /bin/bash -c "test -f /boot/grub/grub.cfg"; then
        print_error "GRUB configuration file not found"
        ((errors++))
    fi
    
    # Check if user was created
    if ! arch-chroot /mnt /bin/bash -c "id $username >/dev/null 2>&1"; then
        print_error "User $username not created"
        ((errors++))
    fi
    
    # Check if network is configured
    if ! arch-chroot /mnt /bin/bash -c "systemctl is-enabled NetworkManager >/dev/null 2>&1"; then
        print_error "NetworkManager not enabled"
        ((errors++))
    fi
    
    # Check if Hyprland is installed
    if ! arch-chroot /mnt /bin/bash -c "test -f /usr/share/wayland-sessions/hyprland.desktop"; then
        print_error "Hyprland not properly installed"
        ((errors++))
    fi
    
    # Check if required services are enabled
    local required_services=(NetworkManager bluetooth docker)
    for service in "${required_services[@]}"; do
        if ! arch-chroot /mnt /bin/bash -c "systemctl is-enabled $service >/dev/null 2>&1"; then
            print_error "Service $service not enabled"
            ((errors++))
        fi
    done
    
    # Add system verification
    if ! verify_system; then
        print_warning "System verification failed"
        print_info "Would you like to attempt automatic repair? [y/N]"
        read -r repair_choice
        if [[ $repair_choice =~ ^[Yy]$ ]]; then
            repair_system
        else
            print_info "You can run system-recovery later to repair the system"
        fi
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "All post-installation checks passed"
        return 0
    else
        print_error "Post-installation checks failed with $errors errors"
        return 1
    fi
}

# Function to create recovery script
create_recovery_script() {
    print_info "Creating recovery script..."
    
    cat > /mnt/usr/local/bin/system-recovery <<EOF
#!/bin/bash

# System Recovery Script
# This script helps fix common issues after installation

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} \$1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} \$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} \$1"
}

# Menu options
while true; do
    clear
    echo "System Recovery Menu"
    echo "1. Rebuild GRUB configuration"
    echo "2. Fix user permissions"
    echo "3. Reinstall graphics drivers"
    echo "4. Reset Hyprland configuration"
    echo "5. Fix network configuration"
    echo "6. Check system status"
    echo "7. Update system"
    echo "8. Create system backup"
    echo "9. Restore system from backup"
    echo "10. View installation logs"
    echo "11. Verify system integrity"
    echo "12. Repair system"
    echo "0. Exit"
    echo
    read -rp "Select an option: " choice
    
    case \$choice in
        1)
            print_info "Rebuilding GRUB configuration..."
            grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        2)
            print_info "Fixing user permissions..."
            chown -R \$USER:\$USER /home/\$USER
            ;;
        3)
            print_info "Reinstalling graphics drivers..."
            if lspci | grep -i "nvidia" >/dev/null; then
                pacman -S --noconfirm nvidia nvidia-utils
            elif lspci | grep -i "amd" >/dev/null; then
                pacman -S --noconfirm xf86-video-amdgpu
            fi
            ;;
        4)
            print_info "Resetting Hyprland configuration..."
            rm -rf ~/.config/hypr
            cp -r /etc/skel/.config/hypr ~/.config/
            ;;
        5)
            print_info "Fixing network configuration..."
            systemctl enable --now NetworkManager
            ;;
        6)
            print_info "Checking system status..."
            systemctl --failed
            journalctl -p 3 -xb
            ;;
        7)
            print_info "Updating system..."
            pacman -Syu
            ;;
        8)
            print_info "Creating system backup..."
            create_system_backup
            ;;
        9)
            print_info "Restoring system from backup..."
            restore_system
            ;;
        10)
            print_info "Viewing installation logs..."
            echo "1. View installation log"
            echo "2. View error log"
            echo "3. View debug log"
            read -rp "Select log to view: " log_choice
            case \$log_choice in
                1) less /var/log/arch-install/install.log ;;
                2) less /var/log/arch-install/error.log ;;
                3) less /var/log/arch-install/debug.log ;;
                *) print_error "Invalid choice" ;;
            esac
            ;;
        11)
            print_info "Verifying system integrity..."
            verify_system
            ;;
        12)
            print_info "Repairing system..."
            repair_system
            ;;
        0)
            exit 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    read -rp "Press Enter to continue..."
done
EOF
    
    chmod +x /mnt/usr/local/bin/system-recovery
    print_success "Recovery script created at /usr/local/bin/system-recovery"
}

# Update main function with new features
main() {
    # Initialize logging
    setup_logging
    log_info "Starting Arch Linux installation with Hyprland"
    
    # Show welcome message and get configuration
    get_user_config
    
    # Initialize progress tracking
    show_progress
    
    # Pre-installation checks
    for step in "check_uefi" "check_internet" "update_clock"; do
        update_step "$step" "In Progress"
        if ! eval "$step"; then
            update_step "$step" "Failed"
            print_error "Pre-installation check failed: $step"
            exit 1
        fi
        update_step "$step" "Done"
    done
    
    # Installation steps
    for step in "${STEPS[@]:3}"; do
        update_step "$step" "In Progress"
        if ! eval "$step"; then
            update_step "$step" "Failed"
            print_error "Installation step failed: $step"
            read -rp "Do you want to retry this step? [Y/n]: " retry
            if [[ $retry =~ ^[Yy]$ ]] || [[ -z $retry ]]; then
                if ! eval "$step"; then
                    print_error "Step failed again, aborting installation"
                    exit 1
                fi
            else
                print_error "Installation aborted"
                exit 1
            fi
        fi
        update_step "$step" "Done"
    done
    
    # Post-installation tasks
    create_recovery_script
    if ! post_install_checks; then
        print_warning "Some post-installation checks failed"
        print_info "You can run 'system-recovery' after booting to fix issues"
    fi
    
    # Finish installation
    print_success "Installation completed successfully!"
    print_info "Please review the following information:"
    echo "1. The system will need to be rebooted"
    echo "2. Log in as user '$username'"
    echo "3. Start Hyprland by typing 'Hyprland'"
    echo "4. If you encounter issues, run 'system-recovery'"
    echo
    print_info "Would you like to reboot now? [Y/n]: "
    read -r reboot_now
    if [[ $reboot_now =~ ^[Yy]$ ]] || [[ -z $reboot_now ]]; then
        umount -R /mnt
        reboot
    fi
}

# Run main function
main 