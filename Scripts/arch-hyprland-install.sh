#!/bin/bash

# Arch Linux + Hyprland Installation Script
# Author: Claude
# Description: Automated installation script for Arch Linux with Hyprland

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Error handling
set -e
trap 'echo -e "${RED}Error: Script failed on line $LINENO${NC}"; exit 1' ERR

# Helper Functions
print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

confirm() {
    read -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Welcome Message
clear
echo -e "${GREEN}Welcome to Arch Linux + Hyprland Installer${NC}"
echo -e "${YELLOW}This script will install and configure Arch Linux with Hyprland${NC}"
echo -e "${RED}WARNING: This script will format the selected drive. Make sure you have backups!${NC}"
sleep 2

# Disk Selection
print_step "Available drives:"
lsblk
echo
read -p "Enter the drive to install Arch Linux (e.g., /dev/sda): " TARGET_DRIVE

if ! confirm "This will ERASE ALL DATA on $TARGET_DRIVE. Are you sure you want to continue?"; then
    echo -e "${RED}Installation cancelled${NC}"
    exit 1
fi

# System Configuration
read -p "Enter hostname: " HOSTNAME
read -p "Enter username: " USERNAME
read -s -p "Enter password for $USERNAME: " USER_PASSWORD
echo
read -s -p "Enter root password: " ROOT_PASSWORD
echo

# Base System Installation
print_step "Partitioning drive"
parted -s "$TARGET_DRIVE" mklabel gpt
parted -s "$TARGET_DRIVE" mkpart primary fat32 1MiB 513MiB
parted -s "$TARGET_DRIVE" set 1 esp on
parted -s "$TARGET_DRIVE" mkpart primary linux-swap 513MiB 8.5GiB
parted -s "$TARGET_DRIVE" mkpart primary ext4 8.5GiB 100%

# Format partitions
print_step "Formatting partitions"
mkfs.fat -F32 "${TARGET_DRIVE}1"
mkswap "${TARGET_DRIVE}2"
mkfs.ext4 "${TARGET_DRIVE}3"

# Mount partitions
print_step "Mounting partitions"
mount "${TARGET_DRIVE}3" /mnt
mkdir -p /mnt/boot/efi
mount "${TARGET_DRIVE}1" /mnt/boot/efi
swapon "${TARGET_DRIVE}2"

# Install base system
print_step "Installing base system"
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab
print_step "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot operations
print_step "Configuring system"
arch-chroot /mnt /bin/bash <<EOF
# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install essential packages
pacman -S --noconfirm \
    networkmanager \
    network-manager-applet \
    wireless_tools \
    wpa_supplicant \
    dialog \
    git \
    base-devel \
    xdg-utils \
    xdg-user-dirs \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    bluez \
    bluez-utils \
    blueman \
    wget \
    curl \
    vim \
    neovim \
    firefox \
    kitty \
    zsh \
    polkit-gnome \
    python \
    python-pip \
    mesa \
    vulkan-intel \
    vulkan-radeon \
    xf86-video-amdgpu \
    xf86-video-intel \
    thunar \
    thunar-archive-plugin \
    file-roller \
    gvfs \
    ntfs-3g \
    htop \
    btop \
    neofetch \
    ranger \
    fzf \
    ripgrep \
    exa \
    bat \
    starship \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-jetbrains-mono-nerd \
    ttf-font-awesome \
    papirus-icon-theme \
    gnome-themes-extra \
    gtk-engine-murrine \
    kvantum \
    qt5ct \
    dunst \
    mpv \
    imv \
    ffmpeg \
    man-db \
    zip \
    unzip \
    p7zip

# Enable services
systemctl enable NetworkManager
systemctl enable bluetooth

# Install yay AUR helper
sudo -u $USERNAME bash -c 'cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm'

# Install Hyprland and dependencies
sudo -u $USERNAME bash -c 'yay -S --noconfirm \
    hyprland \
    waybar-hyprland \
    wofi \
    wlogout \
    swaylock-effects \
    hyprpaper \
    hyprpicker \
    xdg-desktop-portal-hyprland \
    grimblast-git \
    slurp \
    swappy \
    cliphist \
    wl-clipboard \
    pamixer \
    brightnessctl \
    swayidle \
    qt5-wayland \
    qt6-wayland \
    catppuccin-gtk-theme-mocha \
    bibata-cursor-theme \
    sddm-git \
    sddm-catppuccin-git'

# Enable SDDM
systemctl enable sddm

# Create default configuration directories
sudo -u $USERNAME bash -c 'mkdir -p ~/.config/{hypr,waybar,wofi,swaylock,wlogout,dunst,gtk-3.0,gtk-4.0}'

# Set ZSH as default shell
chsh -s /bin/zsh $USERNAME

# Install Oh My Zsh
sudo -u $USERNAME bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'

# Configure environment variables
cat >> /etc/environment <<EOL
QT_QPA_PLATFORMTHEME=qt5ct
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
MOZ_ENABLE_WAYLAND=1
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=Hyprland
GDK_BACKEND=wayland
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
EOL

EOF

# Create Hyprland config
cat > /mnt/home/$USERNAME/.config/hypr/hyprland.conf <<EOL
# Monitor configuration
monitor=,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = hyprpaper
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = wl-clipboard-history -t
exec-once = dunst
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = swayidle -w timeout 300 'swaylock -f' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'

# Set wallpaper
exec-once = swaybg -i /usr/share/backgrounds/default.jpg

# Environment variables
env = XCURSOR_SIZE,24
env = GTK_THEME,Catppuccin-Mocha-Standard-Blue-Dark
env = XCURSOR_THEME,Bibata-Modern-Classic

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
    }
    sensitivity = 0
    accel_profile = flat
}

# General window layout and behavior
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
    cursor_inactive_timeout = 0
    no_cursor_warps = false
}

# Window decoration
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

# Animations
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = linear, 0.0, 0.0, 1.0, 1.0
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layout settings
dwindle {
    pseudotile = true
    preserve_split = true
    force_split = 2
}

master {
    new_is_master = true
    new_on_top = true
}

# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$
windowrule = float, ^(nm-connection-editor)$
windowrule = float, ^(thunar)$
windowrule = float, title:^(Picture-in-Picture)$
windowrule = float, ^(swayimg)$
windowrule = opacity 0.92, ^(kitty)$

# Key bindings
$mainMod = SUPER

# Basic bindings
bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, F, fullscreen,
bind = $mainMod, Space, exec, wofi --show drun
bind = $mainMod, L, exec, swaylock

# Screenshot bindings
bind = , Print, exec, grimblast copy area
bind = SHIFT, Print, exec, grimblast save area
bind = CTRL, Print, exec, grimblast copy output
bind = CTRL SHIFT, Print, exec, grimblast save output

# Audio control
bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
bind = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

# Brightness control
bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Move windows
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, down, movewindow, d

# Resize windows
bind = $mainMod CTRL, left, resizeactive, -20 0
bind = $mainMod CTRL, right, resizeactive, 20 0
bind = $mainMod CTRL, up, resizeactive, 0 -20
bind = $mainMod CTRL, down, resizeactive, 0 20

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
EOL

# Create Waybar config with modern style
cat > /mnt/home/$USERNAME/.config/waybar/config <<EOL
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "margin-top": 6,
    "margin-bottom": 0,
    "margin-left": 6,
    "margin-right": 6,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "battery", "tray"],
    
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5",
            "urgent": "",
            "focused": "",
            "default": ""
        }
    },
    "clock": {
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "format": "{:%H:%M}",
        "format-alt": "{:%Y-%m-%d}"
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
        "format-wifi": " {signalStrength}%",
        "format-ethernet": " {ipaddr}",
        "format-disconnected": "睊",
        "tooltip-format": "{ifname} via {gwaddr}"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "婢",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    "tray": {
        "icon-size": 21,
        "spacing": 10
    }
}
EOL

# Create Waybar style
cat > /mnt/home/$USERNAME/.config/waybar/style.css <<EOL
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 14px;
    min-height: 0;
}

window#waybar {
    background: rgba(30, 30, 46, 0.5);
    color: #cdd6f4;
    border-radius: 15px;
}

#workspaces button {
    padding: 0 5px;
    color: #cdd6f4;
}

#workspaces button.active {
    color: #89b4fa;
}

#clock,
#battery,
#cpu,
#memory,
#network,
#pulseaudio,
#tray {
    padding: 0 10px;
    margin: 6px 0;
    color: #cdd6f4;
}

#tray {
    border-radius: 15px;
    margin-right: 4px;
}

#workspaces {
    background: #1e1e2e;
    border-radius: 15px;
    margin-left: 4px;
    padding-right: 4px;
    padding-left: 4px;
}

#window {
    border-radius: 15px;
    margin-left: 8px;
    margin-right: 8px;
}

#clock {
    color: #89b4fa;
    border-radius: 15px;
    margin-left: 4px;
    margin-right: 4px;
}

#network {
    color: #89b4fa;
    border-radius: 15px 0px 0px 15px;
    margin-left: 4px;
}

#pulseaudio {
    color: #89b4fa;
    border-radius: 15px;
    margin-right: 4px;
}

#battery {
    color: #a6e3a1;
    border-radius: 0px 15px 15px 0px;
    margin-right: 4px;
}

#battery.charging {
    color: #a6e3a1;
}

#battery.warning:not(.charging) {
    background: #f38ba8;
    color: #1e1e2e;
    border-radius: 15px;
}
EOL

# Create Wofi style
mkdir -p /mnt/home/$USERNAME/.config/wofi
cat > /mnt/home/$USERNAME/.config/wofi/style.css <<EOL
window {
    margin: 0px;
    border: 2px solid #89b4fa;
    border-radius: 15px;
    background-color: #1e1e2e;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 14px;
}

#input {
    margin: 5px;
    border: none;
    color: #cdd6f4;
    background-color: #313244;
    border-radius: 15px;
}

#inner-box {
    margin: 5px;
    border: none;
    background-color: #1e1e2e;
    border-radius: 15px;
}

#outer-box {
    margin: 5px;
    border: none;
    background-color: #1e1e2e;
    border-radius: 15px;
}

#scroll {
    margin: 0px;
    border: none;
}

#text {
    margin: 5px;
    border: none;
    color: #cdd6f4;
} 

#entry:selected {
    background-color: #89b4fa;
    border-radius: 15px;
    outline: none;
}

#text:selected {
    color: #1e1e2e;
}
EOL

# Create dunst config
mkdir -p /mnt/home/$USERNAME/.config/dunst
cat > /mnt/home/$USERNAME/.config/dunst/dunstrc <<EOL
[global]
    monitor = 0
    follow = mouse
    width = 300
    height = 300
    origin = top-right
    offset = 10x50
    scale = 0
    notification_limit = 0
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 0
    separator_height = 2
    padding = 8
    horizontal_padding = 8
    text_icon_padding = 0
    frame_width = 2
    frame_color = "#89b4fa"
    separator_color = frame
    sort = yes
    font = JetBrainsMono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 0
    max_icon_size = 32
    icon_path = /usr/share/icons/Papirus-Dark/16x16/status/:/usr/share/icons/Papirus-Dark/16x16/devices/:/usr/share/icons/Papirus-Dark/16x16/apps/
    sticky_history = yes
    history_length = 20
    always_run_script = true
    corner_radius = 10
    ignore_dbusclose = false
    force_xinerama = false
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[urgency_low]
    background = "#1E1E2E"
    foreground = "#CDD6F4"
    timeout = 10

[urgency_normal]
    background = "#1E1E2E"
    foreground = "#CDD6F4"
    timeout = 10

[urgency_critical]
    background = "#1E1E2E"
    foreground = "#CDD6F4"
    frame_color = "#FAB387"
    timeout = -1
    format = "<b>%s</b>\n%b"
EOL

# Create swaylock config
cat > /mnt/home/$USERNAME/.config/swaylock/config <<EOL
ignore-empty-password
font=JetBrainsMono Nerd Font

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

key-hl-color=89b4fa

separator-color=00000000

inside-color=1e1e2e
inside-clear-color=1e1e2e
inside-caps-lock-color=1e1e2e
inside-ver-color=1e1e2e
inside-wrong-color=1e1e2e

ring-color=313244
ring-clear-color=89b4fa
ring-caps-lock-color=fab387
ring-ver-color=89b4fa
ring-wrong-color=f38ba8

line-color=00000000
line-clear-color=00000000
line-caps-lock-color=00000000
line-ver-color=00000000
line-wrong-color=00000000

text-color=cdd6f4
text-clear-color=cdd6f4
text-ver-color=cdd6f4
text-wrong-color=f38ba8

bs-hl-color=f38ba8
caps-lock-key-hl-color=fab387
caps-lock-bs-hl-color=f38ba8
text-caps-lock-color=cdd6f4
EOL

# Configure GTK theme
cat > /mnt/home/$USERNAME/.config/gtk-3.0/settings.ini <<EOL
[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Bibata-Modern-Classic
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

# Set up Zsh configuration
cat > /mnt/home/$USERNAME/.zshrc <<EOL
# Enable Powerlevel10k instant prompt
if [[ -r "\${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='nvim'
export VISUAL='nvim'
export TERMINAL='kitty'
export BROWSER='firefox'

# Aliases
alias ls='exa --icons'
alias ll='exa -l --icons'
alias la='exa -la --icons'
alias cat='bat'
alias vim='nvim'
alias top='btop'
alias update='yay -Syu'

# Initialize starship prompt
eval "$(starship init zsh)"
EOL

# Install additional Zsh plugins
sudo -u $USERNAME bash -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
sudo -u $USERNAME bash -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

# Configure Starship prompt
mkdir -p /mnt/home/$USERNAME/.config
cat > /mnt/home/$USERNAME/.config/starship.toml <<EOL
format = """
[](#89b4fa)\
$directory\
[](bg:#89b4fa fg:#89b4fa)\
$git_branch\
$git_status\
[](#89b4fa)\
$character"""

[directory]
style = "bg:#89b4fa fg:#1e1e2e"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = ""
style = "bg:#89b4fa fg:#1e1e2e"
format = '[[ $symbol $branch ](bg:#89b4fa fg:#1e1e2e)]($style)'

[git_status]
style = "bg:#89b4fa fg:#1e1e2e"
format = '[[($all_status$ahead_behind )](bg:#89b4fa fg:#1e1e2e)]($style)'

[character]
success_symbol = "[❯](purple)"
error_symbol = "[❯](red)"
vimcmd_symbol = "[❮](green)"
EOL

# Set permissions
chown -R $USERNAME:$USERNAME /mnt/home/$USERNAME/.config
chown -R $USERNAME:$USERNAME /mnt/home/$USERNAME/.zshrc
chown -R $USERNAME:$USERNAME /mnt/home/$USERNAME/.oh-my-zsh

print_step "Installation complete!"
echo -e "${GREEN}Please reboot your system and login as $USERNAME${NC}"
echo -e "${YELLOW}After reboot, start Hyprland by typing 'Hyprland' at the terminal${NC}" 