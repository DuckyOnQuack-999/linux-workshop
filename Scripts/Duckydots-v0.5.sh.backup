#!/usr/bin/env bash

# Enhanced Hyprland Advanced Extras Installation Script
# Features: Modular configuration, reset dialog with forced fresh start, robust error handling, logging, and system integration

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# === Global Variables and Setup ===

# Declare pkg_cache globally
declare -A pkg_cache

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
mkdir -p "$HOME/.cache/hyprland"
LOG_FILE="$HOME/.cache/hyprland/install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Logging functions with timestamps
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1"
}

# Error handling
handle_error() {
    log_error "Script failed at line $1"
    log_error "Command: $2"
    exit 1
}
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# === Initial Checks ===

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
fi

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    log_error "yay is not installed. Please install it first:"
    log_info "git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
    exit 1
fi

# Check if pip and pipx are installed
if ! command -v pip &> /dev/null; then
    log_warning "pip not found, installing python-pip..."
    sudo pacman -S --needed python-pip || {
        log_error "Failed to install python-pip"
        exit 1
    }
fi

if ! command -v pipx &> /dev/null; then
    log_warning "pipx not found, installing python-pipx..."
    sudo pacman -S --needed python-pipx || {
        log_error "Failed to install python-pipx"
        exit 1
    }
fi

# Ensure user local bin is on PATH for pipx
export PATH="$HOME/.local/bin:$PATH"

# Check for yad (for reset dialog)
if ! command -v yad &> /dev/null; then
    log_warning "yad not found, installing for reset dialog..."
    yay -S --needed yad || {
        log_error "Failed to install yad"
        exit 1
    }
fi

# Check package installation status
check_package() {
    local pkg="$1"
    # Check if the package key exists in the cache
    if [[ ! -v "pkg_cache[$pkg]" ]]; then
        if pacman -Qi "$pkg" &> /dev/null; then
            pkg_cache[$pkg]="installed"
        else
            pkg_cache[$pkg]="missing"
        fi
    fi
    [[ "${pkg_cache[$pkg]:-}" == "installed" ]]
}

# === Helper Functions ===

# Backup existing configurations
backup_config() {
    local config_dir="$HOME/.config/hypr"
    if [[ -d "$config_dir" ]]; then
        local backup_dir="$HOME/.config/hypr/backups/$(date '+%Y-%m-%d_%H.%M.%S')"
        log_info "Backing up $config_dir to $backup_dir"
        mkdir -p "$backup_dir"
        # Exclude the backups directory to prevent recursive copying
        find "$config_dir" -maxdepth 1 -not -path "$config_dir" -not -path "$config_dir/backups" -exec cp -r {} "$backup_dir/" \; || {
            log_error "Failed to backup $config_dir"
            exit 1
        }
        chmod 700 "$backup_dir"
    fi
}

# Check GPU drivers
check_gpu_drivers() {
    log_info "Checking for GPU drivers..."
    local drivers=("mesa" "nvidia" "amdvlk")
    local found=false
    for driver in "${drivers[@]}"; do
        if check_package "$driver"; then
            log_success "$driver is installed"
            found=true
        fi
    done
    if [[ "$found" == false ]]; then
        log_warning "No GPU drivers detected. Install appropriate drivers (e.g., mesa, nvidia, amdvlk) for optimal performance."
        log_info "Example: sudo pacman -S mesa"
    fi
}

# Resolve package conflicts
resolve_conflicts() {
    log_info "Resolving package conflicts..."
    local conflicts=("xdg-desktop-portal-hyprland" "hyprlang" "hyprutils" "waybar" "waybar-git")
    for conflict in "${conflicts[@]}"; do
        if check_package "$conflict"; then
            log_warning "Removing conflicting package: $conflict"
            yay -R --noconfirm "$conflict" 2>/dev/null || true
        fi
    done
    yay -Sy || {
        log_error "Failed to sync package database"
        exit 1
    }
}

# Create file with heredoc
create_file() {
    local file="$1"
    local content="$2"
    cat << EEOF > "$file"
$content
EEOF
    chmod +x "$file"  # Make executable if script
    log_success "Created $file"
}

# === Package Installation ===

log_info "Installing packages..."

# Check hyprpm dependencies
hyprpm_deps=("cmake" "meson" "cpio" "pkg-config" "git" "gcc" "g++")
missing_hyprpm_deps=()
for dep in "${hyprpm_deps[@]}"; do
    if ! check_package "$dep"; then
        missing_hyprpm_deps+=("$dep")
    fi
done
if [[ ${#missing_hyprpm_deps[@]} -gt 0 ]]; then
    log_info "Installing missing hyprpm dependencies: ${missing_hyprpm_deps[*]}"
    yay -S --needed "${missing_hyprpm_deps[@]}" || {
        log_error "Failed to install hyprpm dependencies"
        exit 1
    }
fi

# Install core packages in parallel
yay -S --needed --noconfirm \
    hyprland \
    hyprpaper \
    eww-wayland \
    foot \
    fuzzel \
    playerctl \
    wlsunset \
    hyprcursor \
    hyprkeys \
    hyprshot \
    swaync \
    swayosd \
    hyprnome \
    wluma \
    hyprdim \
    gtklock \
    gtklock-powerbar-module \
    gtklock-userinfo-module \
    wob \
    swww \
    cliphist \
    wl-clipboard \
    hypridle \
    hyprlock \
    mako \
    networkmanager \
    blueman \
    polkit-kde-agent \
    systemd \
    jq \
    wf-recorder \
    slurp \
    libnotify \
    fcitx5 \
    fcitx5-configtool \
    pywal-git \
    waybar-module-pacman-updates-git \
    waybar-module-weather-git \
    hyperpaper &

# Install AUR packages
yay -S --needed pyprland quickshell &

# Install hyprpm
if ! command -v hyprpm &> /dev/null; then
    log_warning "hyprpm not found, installing..."
    yay -S --needed hyprpm || {
        log_error "Failed to install hyprpm"
        exit 1
    }
fi

# Wait for background tasks
wait

# Install potentially conflicting packages
if ! yay -S --needed xdg-desktop-portal-hyprland-git 2>/dev/null; then
    log_warning "xdg-desktop-portal-hyprland-git failed, trying stable version..."
    if ! yay -S --needed xdg-desktop-portal-hyprland 2>/dev/null; then
        log_warning "Both versions failed, skipping xdg-desktop-portal-hyprland"
    fi
fi

if ! yay -S --needed hyperpaper 2>/dev/null; then
    log_warning "hyperpaper not available, skipping..."
fi

# Install pywal
log_info "Installing pywal via pipx..."
pipx install pywal || {
    log_error "Failed to install pywal"
    exit 1
} &

# Wait for pipx
wait

# Update Hyprland plugins
log_info "Updating Hyprland plugins..."
if command -v hyprpm &> /dev/null; then
    if hyprpm update; then
        log_success "Hyprland plugins updated"
    else
        log_error "Failed to update Hyprland plugins"
        exit 1
    fi
else
    log_error "hyprpm installation failed, skipping plugin update"
    exit 1
fi

# Validate essential packages
essential_packages=(
    "hyprland" "hypridle" "hyprlock" "mako" "swww" "wl-clipboard"
    "cliphist" "fuzzel" "foot" "jq" "wf-recorder" "slurp" "libnotify" "fcitx5"
)
missing_packages=()
for package in "${essential_packages[@]}"; do
    if ! check_package "$package"; then
        missing_packages+=("$package")
    fi
done

if [[ ${#missing_packages[@]} -gt 0 ]]; then
    log_error "Missing essential packages: ${missing_packages[*]}"
    log_info "Attempting to install missing packages..."
    yay -S --needed --noconfirm "${missing_packages[@]}" || {
        log_error "Failed to install missing packages"
        exit 1
    } &
    wait
fi

log_success "Package installation completed"

# === Configuration Setup ===

# Create configuration directories
mkdir -p "$HOME/.config/hypr" "$HOME/.config/hypr/scripts" "$HOME/.config/fcitx5"

# Backup existing configurations
backup_config

# Check GPU drivers
check_gpu_drivers

# Resolve conflicts
resolve_conflicts

# Configuration file creation functions
create_general_conf() {
    create_file "$HOME/.config/hypr/general.conf" '# Main Hyprland configuration file
# Sources modular configuration files
source = ~/.config/hypr/colors.conf
source = ~/.config/hypr/rules.conf
source = ~/.config/hypr/keybinds.conf
source = ~/.config/hypr/env.conf
source = ~/.config/hypr/execs.conf
source = ~/.config/hypr/hyprpaper.conf
source = ~/.config/hypr/hypridle.conf
source = ~/.config/hypr/hyprlock.conf

# Monitor configuration
monitor = ,preferred,auto,279.99
monitor = ,highrr,auto,143.99

# Advanced gesture configuration
gesture = 3, swipe, move,
gesture = 4, horizontal, workspace
gesture = 4, pinch, float
gesture = 4, up, dispatcher, global, quickshell:overviewToggle
gesture = 4, down, dispatcher, global, quickshell:overviewClose
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
    workspace_swipe_create_new = true
    workspace_swipe_forever = true
    workspace_swipe_direction_lock = true
    workspace_swipe_direction_lock_threshold = 10
}

# Animation settings
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = linear, 0.0, 0.0, 1.0, 1.0
    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = winOut, 0.3, -0.3, 0, 1
    bezier = slow, 0, 0.85, 0.3, 1
    animation = windows, 1, 6, wind, slide
    animation = windowsIn, 1, 6, winIn, slide
    animation = windowsOut, 1, 5, winOut, slide
    animation = windowsMove, 1, 5, wind, slide
    animation = border, 1, 1, linear
    animation = borderangle, 1, 30, linear, loop
    animation = fade, 1, 5, default
    animation = workspaces, 1, 5, wind
    animation = specialWorkspace, 1, 5, slow, slidevert
}

# Decoration settings
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 5
        passes = 3
        new_optimizations = true
        xray = true
        ignore_opacity = true
    }
    active_opacity = 0.95
    inactive_opacity = 0.85
    fullscreen_opacity = 1.0
    drop_shadow = true
    shadow_range = 12
    shadow_offset = 3 3
    shadow_render_power = 4
    col.shadow = rgba(1a1a1aee)
    dim_inactive = true
    dim_strength = 0.1
    popups = true
    popups_ignorealpha = 0.6
    input_methods = true
    input_methods_ignorealpha = 0.8
}

# Enhanced input configuration
input {
    kb_layout = us
    kb_options = caps:super
    numlock_by_default = true
    repeat_delay = 250
    repeat_rate = 35
    follow_mouse = 2
    off_window_axis_events = 2
    sensitivity = 0
    natural_scroll = true
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
        disable_while_typing = true
        middle_button_emulation = true
        tap-and-drag = true
        clickfinger_behavior = true
        scroll_factor = 0.5
    }
    accel_profile = flat
}

# General settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(ff92a6ee) rgba(94bfd1ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
    no_focus_fallback = true
    allow_tearing = true
    snap {
        enabled = true
        window_gap = 4
        monitor_gap = 5
        respect_gaps = true
    }
}

# Advanced dwindle layout
dwindle {
    pseudotile = true
    preserve_split = true
    special_scale_factor = 0.8
    split_width_multiplier = 1.0
    no_gaps_when_only = false
    use_active_for_splits = true
    force_split = 2
}

# Master layout
master {
    new_is_master = true
    new_on_top = true
    mfact = 0.5
    special_scale_factor = 0.8
    no_gaps_when_only = false
}

# Miscellaneous settings
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    vfr = 1
    vrr = 1
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    animate_manual_resizes = false
    animate_mouse_windowdragging = false
    enable_swallow = false
    swallow_regex = (foot|kitty|allacritty|Alacritty)
    new_window_takes_over_fullscreen = 2
    allow_session_lock_restore = true
    session_lock_xray = true
    initial_workspace_tracking = false
    focus_on_activate = true
    cursor_inactive_timeout = 5
}

# Binds settings
binds {
    scroll_event_delay = 0
    hide_special_on_workspace_change = true
}

# Cursor settings
cursor {
    zoom_factor = 1
    zoom_rigid = false
    hotspot_padding = 1
}

# Mouse bindings
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
bindm = SUPER ALT, mouse:272, resizewindow

# Touchpad gesture binds
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
bindm = SUPER ALT, mouse:272, resizewindow

# Workspace configurations
workspace = 1, name:DEV, default:true, persistent:true, border_size:3
workspace = 2, name:WWW, default:true, persistent:true
workspace = 3, name:CHAT, default:true, persistent:true
workspace = 4, name:MUSIC, default:true, persistent:true
workspace = 5, name:GAMES, default:true, persistent:true
workspace = special:scratchpad, on-created-empty:kitty
workspace = special:special, gapsout:30

# Hyprexpo plugin
plugin {
    hyprexpo {
        columns = 3
        gap_size = 5
        bg_col = rgb(000000)
        workspace_method = first 1
        enable_gesture = false
        gesture_distance = 300
        gesture_positive = false
    }
}'
}

create_colors_conf() {
    create_file "$HOME/.config/hypr/colors.conf" '# Color scheme configuration
general {
    col.active_border = rgba(90909aAA)
    col.inactive_border = rgba(46464fAA)
}

misc {
    background_color = rgba(121318FF)
}

plugin {
    hyprbars {
        bar_text_font = Rubik, Geist, AR One Sans, Reddit Sans, Inter, Roboto, Ubuntu, Noto Sans, sans-serif
        bar_height = 30
        bar_padding = 10
        bar_button_padding = 5
        bar_precedence_over_border = true
        bar_part_of_window = true
        bar_color = rgba(121318FF)
        col.text = rgba(e3e1e9FF)
        
        hyprbars-button = rgb(e3e1e9), 13, 󰖭, hyprctl dispatch killactive
        hyprbars-button = rgb(e3e1e9), 13, 󰖯, hyprctl dispatch fullscreen 1
        hyprbars-button = rgb(e3e1e9), 13, 󰖰, hyprctl dispatch movetoworkspacesilent special
    }
}

windowrulev2 = bordercolor rgba(bac3ffAA) rgba(bac3ff77),pinned:1'
}

create_rules_conf() {
    create_file "$HOME/.config/hypr/rules.conf" '# Window and layer rules
windowrulev2 = opacity 0.89 override 0.89 override, class:.*
windowrulev2 = noblur, xwayland:1
windowrulev2 = center, title:^(Open File)(.*)$
windowrulev2 = float, title:^(Open File)(.*)$
windowrulev2 = center, title:^(Select a File)(.*)$
windowrulev2 = float, title:^(Select a File)(.*)$
windowrulev2 = center, title:^(Choose wallpaper)(.*)$
windowrulev2 = float, title:^(Choose wallpaper)(.*)$
windowrulev2 = size 60% 65%, title:^(Choose wallpaper)(.*)$
windowrulev2 = center, title:^(Open Folder)(.*)$
windowrulev2 = float, title:^(Open Folder)(.*)$
windowrulev2 = center, title:^(Save As)(.*)$
windowrulev2 = float, title:^(Save As)(.*)$
windowrulev2 = center, title:^(Library)(.*)$
windowrulev2 = float, title:^(Library)(.*)$
windowrulev2 = center, title:^(File Upload)(.*)$
windowrulev2 = float, title:^(File Upload)(.*)$
windowrulev2 = center, title:^(.*)(wants to save)$
windowrulev2 = float, title:^(.*)(wants to save)$
windowrulev2 = center, title:^(.*)(wants to open)$
windowrulev2 = float, title:^(.*)(wants to open)$
windowrulev2 = float, class:^(blueberry\.py)$
windowrulev2 = float, class:^(guifetch)$
windowrulev2 = float, class:^(pavucontrol)$
windowrulev2 = size 45%, class:^(pavucontrol)$
windowrulev2 = center, class:^(pavucontrol)$
windowrulev2 = float, class:^(org.pulseaudio.pavucontrol)$
windowrulev2 = size 45%, class:^(org.pulseaudio.pavucontrol)$
windowrulev2 = center, class:^(org.pulseaudio.pavucontrol)$
windowrulev2 = float, class:^(nm-connection-editor)$
windowrulev2 = size 45%, class:^(nm-connection-editor)$
windowrulev2 = center, class:^(nm-connection-editor)$
windowrulev2 = float, class:.*plasmawindowed.*
windowrulev2 = float, class:kcm_.*
windowrulev2 = float, class:.*bluedevilwizard
windowrulev2 = float, title:.*Welcome
windowrulev2 = float, title:^(illogical-impulse Settings)$
windowrulev2 = float, title:.*Shell conflicts.*
windowrulev2 = float, class:org.freedesktop.impl.portal.desktop.kde
windowrulev2 = size 60% 65%, class:org.freedesktop.impl.portal.desktop.kde
windowrulev2 = float, class:^(Zotero)$
windowrulev2 = size 45%, class:^(Zotero)$
windowrulev2 = float, class:^(plasma-changeicons)$
windowrulev2 = noinitialfocus, class:^(plasma-changeicons)$
windowrulev2 = move 999999 999999, class:^(plasma-changeicons)$
windowrulev2 = move 40 80, title:^(Copying — Dolphin)$
windowrulev2 = tile, class:^dev\.warp\.Warp$
windowrulev2 = float, title:^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$
windowrulev2 = keepaspectratio, title:^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$
windowrulev2 = move 73% 72%, title:^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$ 
windowrulev2 = size 25%, title:^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$
windowrulev2 = pin, title:^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$
windowrulev2 = immediate, title:.*\.exe
windowrulev2 = immediate, title:.*minecraft.*
windowrulev2 = immediate, class:^(steam_app).*
windowrulev2 = noshadow, floating:0
windowrulev2 = float,class:^(pavucontrol)$
windowrulev2 = float,title:^(Picture-in-Picture)$
windowrulev2 = float,class:^(blueman-manager)$
windowrulev2 = float,class:^(org.kde.polkit-kde-authentication-agent-1)$
windowrulev2 = float,class:^(firefox)$,title:^(Library)$
windowrulev2 = workspace 1 silent,class:^(kitty)$
windowrulev2 = workspace 2 silent,class:^(firefox)$
windowrulev2 = workspace 3 silent,class:^(discord)$
windowrulev2 = workspace 4 silent,class:^(spotify)$
windowrulev2 = opacity 0.9,class:^(kitty)$
windowrulev2 = opacity 0.9,class:^(thunar)$

# Layer rules
layerrule = xray 1, .*
layerrule = noanim, walker
layerrule = noanim, selection
layerrule = noanim, overview
layerrule = noanim, anyrun
layerrule = noanim, indicator.*
layerrule = noanim, osk
layerrule = noanim, hyprpicker
layerrule = noanim, noanim
layerrule = blur, gtk-layer-shell
layerrule = ignorezero, gtk-layer-shell
layerrule = blur, launcher
layerrule = ignorealpha 0.5, launcher
layerrule = blur, notifications
layerrule = ignorealpha 0.69, notifications
layerrule = blur, logout_dialog
layerrule = animation slide left, sideleft.*
layerrule = animation slide right, sideright.*
layerrule = blur, session[0-9]*
layerrule = blur, bar[0-9]*
layerrule = ignorealpha 0.6, bar[0-9]*
layerrule = blur, barcorner.*
layerrule = ignorealpha 0.6, barcorner.*
layerrule = blur, dock[0-9]*
layerrule = ignorealpha 0.6, dock[0-9]*
layerrule = blur, indicator.*
layerrule = ignorealpha 0.6, indicator.*
layerrule = blur, overview[0-9]*
layerrule = ignorealpha 0.6, overview[0-9]*
layerrule = blur, cheatsheet[0-9]*
layerrule = ignorealpha 0.6, cheatsheet[0-9]*
layerrule = blur, sideright[0-9]*
layerrule = ignorealpha 0.6, sideright[0-9]*
layerrule = blur, sideleft[0-9]*
layerrule = ignorealpha 0.6, sideleft[0-9]*
layerrule = blur, indicator.*
layerrule = ignorealpha 0.6, indicator.*
layerrule = blur, osk[0-9]*
layerrule = ignorealpha 0.6, osk[0-9]*
layerrule = blurpopups, quickshell:.*
layerrule = blur, quickshell:.*
layerrule = ignorealpha 0.79, quickshell:.*
layerrule = animation slide, quickshell:bar
layerrule = animation slide, quickshell:verticalBar
layerrule = animation fade, quickshell:screenCorners
layerrule = animation slide right, quickshell:sidebarRight
layerrule = animation slide left, quickshell:sidebarLeft
layerrule = animation slide top, quickshell:wallpaperSelector
layerrule = animation slide bottom, quickshell:osk
layerrule = animation slide bottom, quickshell:dock
layerrule = animation slide bottom, quickshell:cheatsheet
layerrule = blur, quickshell:session
layerrule = noanim, quickshell:session
layerrule = ignorealpha 0, quickshell:session
layerrule = animation fade, quickshell:notificationPopup
layerrule = blur, quickshell:backgroundWidgets
layerrule = ignorealpha 0.05, quickshell:backgroundWidgets
layerrule = noanim, quickshell:screenshot
layerrule = animation popin 120%, quickshell:screenCorners
layerrule = noanim, quickshell:lockWindowPusher
layerrule = blur, shell:bar
layerrule = ignorezero, shell:bar
layerrule = blur, shell:notifications
layerrule = ignorealpha 0.1, shell:notifications'
}

create_keybinds_conf() {
    create_file "$HOME/.config/hypr/keybinds.conf" '# Keybindings for Hyprland
$mainMod = SUPER

# Window management
bind = $mainMod, Q, killactive,
bind = $mainMod SHIFT, Q, exec, ~/.config/hypr/scripts/close-all-windows.sh
bind = $mainMod, F, fullscreen, 1
bind = $mainMod SHIFT, F, fullscreen, 0
bind = $mainMod, V, togglefloating,
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Workspace management
bind = $mainMod SHIFT, right, movetoworkspace, +1
bind = $mainMod SHIFT, left, movetoworkspace, -1
bind = $mainMod CTRL, right, workspace, +1
bind = $mainMod CTRL, left, workspace, -1
bind = $mainMod ALT, up, movetoworkspace, special:scratchpad
bind = $mainMod ALT, down, togglespecialworkspace, scratchpad

# Media controls
bind = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise
bind = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower
bind = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
bind = , XF86MonBrightnessUp, exec, swayosd-client --brightness raise
bind = , XF86MonBrightnessDown, exec, swayosd-client --brightness lower

# Screenshot utilities
bind = , Print, exec, hyprshot -m output --clipboard-only
bind = SHIFT, Print, exec, hyprshot -m region --clipboard-only
bind = CTRL, Print, exec, hyprshot -m window --clipboard-only

# Visual effects
bind = $mainMod, B, exec, ~/.config/hypr/scripts/toggle-blur.sh
bind = $mainMod, O, exec, ~/.config/hypr/scripts/toggle-opacity.sh
bind = $mainMod SHIFT, N, exec, swaync-client -t

# Wallpaper management
bind = $mainMod, W, exec, ~/.config/hypr/scripts/wallpaper-manager.sh
bind = $mainMod SHIFT, W, exec, ~/.config/hypr/scripts/generate-colors.sh

# System controls
bind = $mainMod, L, exec, hyprlock
bind = $mainMod SHIFT, L, exec, systemctl suspend
bind = $mainMod CTRL, L, exec, systemctl poweroff
bind = $mainMod SHIFT, R, exec, ~/.config/hypr/scripts/reset-hyprland.sh

# Quick settings
bind = $mainMod, B, exec, ~/.config/hypr/scripts/toggle-blur.sh
bind = $mainMod, O, exec, ~/.config/hypr/scripts/toggle-opacity.sh
bind = $mainMod SHIFT, N, exec, swaync-client -t'
}

create_hyprpaper_conf() {
    create_file "$HOME/.config/hypr/hyprpaper.conf" '# Hyprpaper configuration
preload = ~/wallpaper.jpg
wallpaper = ,~/wallpaper.jpg
splash = false'
}

create_hypridle_conf() {
    create_file "$HOME/.config/hypr/hypridle.conf" '# Hypridle configuration
general {
    lock_cmd = hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
    ignore_dbus_inhibit = false
}

listener {
    timeout = 300
    on-timeout = hyprlock
}

listener {
    timeout = 600
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 1800
    on-timeout = systemctl suspend
}'
}

create_hyprlock_conf() {
    create_file "$HOME/.config/hypr/hyprlock.conf" '# Hyprlock configuration
general {
    disable_loading_bar = false
    grace = 0
    no_fade_in = false
    no_fade_out = false
    ignore_empty_input = true
    hide_cursor = true
}

background {
    monitor =
    path = ~/wallpaper.jpg
    blur_passes = 3
    blur_size = 5
    noise = 0.0117
    contrast = 0.8000
    brightness = 0.8000
    vibrancy = 0.2100
    vibrancy_darkness = 0.0
}

input-field {
    monitor =
    size = 200, 50
    outline_thickness = 3
    dots_size = 0.35
    dots_spacing = 0.15
    dots_center = true
    outer_color = rgba(0, 0, 0, 0)
    inner_color = rgba(0, 0, 0, 0.5)
    font_color = rgb(200, 200, 200)
    fade_on_empty = true
    placeholder_text = <i>Password...</i>
    hide_input = false
    position = 0, -20
    halign = center
    valign = center
}

label {
    monitor =
    text = Hi there, $USER
    color = rgba(200, 200, 200, 1.0)
    font_size = 25
    font_family = SauceCodePro Nerd Font Propo
    position = 0, 0
    halign = center
    valign = center
}

label {
    monitor =
    text = $TIME
    color = rgba(200, 200, 200, 1.0)
    font_size = 55
    font_family = SauceCodePro Nerd Font Propo
    position = 0, -200
    halign = center
    valign = center
}'
}

create_env_conf() {
    create_file "$HOME/.config/hypr/env.conf" '# Environment variables
env = QT_IM_MODULE,fcitx
env = XMODIFIERS,@im=fcitx
env = SDL_IM_MODULE,fcitx
env = GLFW_IM_MODULE,ibus
env = INPUT_METHOD,fcitx
env = ELECTRON_OZONE_PLATFORM_HINT,auto
env = MOZ_ENABLE_WAYLAND,1
env = QT_QPA_PLATFORM,wayland
env = QT_QPA_PLATFORMTHEME,qt5ct
env = XDG_MENU_PREFIX,plasma-
env = XCURSOR_SIZE,24
env = HYPRCURSOR_THEME,HyprBibataModernClassicSVG
env = HYPRCURSOR_SIZE,24
env = WLR_NO_HARDWARE_CURSORS,1
env = ILLOGICAL_IMPULSE_VIRTUAL_ENV,~/.local/state/quickshell/.venv
env = TERMINAL,kitty -1'
}

create_execs_conf() {
    create_file "$HOME/.config/hypr/execs.conf" '# Startup commands
exec-once = hyprpaper
exec-once = swww init
exec-once = ~/.config/hypr/scripts/start_geoclue_agent.sh
exec-once = fcitx5
exec-once = mako
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = gnome-keyring-daemon --start --components=secrets
exec-once = ~/.config/hypr/scripts/launch_polkit.sh
exec-once = swayosd-server
exec-once = hypridle
exec-once = dbus-update-activation-environment --all
exec-once = sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = ~/.config/hypr/scripts/sleep.sh
exec-once = hyprpm reload
exec-once = easyeffects --gapplication-service
exec-once = wl-paste --type text --watch bash -c "cliphist store && command -v qs >/dev/null 2>&1 && qs ipc call cliphistService update"
exec-once = wl-paste --type image --watch bash -c "cliphist store && command -v qs >/dev/null 2>&1 && qs ipc call cliphistService update"
exec-once = hyprctl setcursor Bibata-Modern-Classic 24
exec-once = wluma
exec-once = pypr
exec-once = swww img ~/wallpaper.jpg --transition-fps 75 --transition-type wipe
exec-once = waybar & mako & nm-applet --indicator & blueman-applet
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = wl-paste --watch cliphist store
exec-once = swayosd-server
exec-once = hypridle
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = ~/.config/hypr/scripts/sleep.sh
exec-once = wluma
exec-once = pypr'
}

create_fcitx5_conf() {
    create_file "$HOME/.config/fcitx5/config" '[InputMethod]
ActiveByDefault=false
ShowInputMethodInformation=true
ShowInputMethodInformationWhenFocusIn=true
VerticalCandidateList=false
WheelForPaging=true
Font=Sans 10
MenuFont=Sans 10
TrayFont=Sans 10
PreferPinyinMode=false
ShowPreeditInApplication=true

[Hotkey]
Trigger=Control+Shift+space
AltTrigger=
EnumerateForwardKeys=
EnumerateBackwardKeys=
EnumerateSkipFirst=false
ActivateKeys=
DeactivateKeys=
ToggleKeys=
PrevPage=Up
NextPage=Down
PrevCandidate=Shift+Tab
NextCandidate=Tab'
}

# Create all configuration files in parallel
create_general_conf &
create_colors_conf &
create_rules_conf &
create_keybinds_conf &
create_hyprpaper_conf &
create_hypridle_conf &
create_hyprlock_conf &
create_env_conf &
create_execs_conf &
create_fcitx5_conf &
wait

log_success "Configuration files created"

# === Utility Scripts ===

create_script() {
    local file="$1"
    local content="$2"
    create_file "$file" "$content"
}

# Reset Hyprland configuration
create_script "$HOME/.config/hypr/scripts/reset-hyprland.sh" '#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/hypr"
BACKUP_DIR="$HOME/.config/hypr/backups/$(date +%Y-%m-%d_%H.%M.%S)"
INSTALL_SCRIPT="$HOME/.config/hypr/scripts/hyprland-advanced-extras-enhanced.sh"

# Backup existing configuration
backup_config() {
    if [[ -d "$CONFIG_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$CONFIG_DIR"/* "$BACKUP_DIR/" || {
            echo "Error: Failed to backup $CONFIG_DIR"
            exit 1
        }
        chmod 700 "$BACKUP_DIR"
        echo "Backed up configuration to $BACKUP_DIR"
    fi
}

# Reset configuration directory
reset_config() {
    if [[ -z "$CONFIG_DIR" || "$CONFIG_DIR" == "/" || "$CONFIG_DIR" == "$HOME" ]]; then
        echo "Error: Invalid CONFIG_DIR: $CONFIG_DIR"
        exit 1
    fi
    if [[ -d "$CONFIG_DIR" ]]; then
        backup_config
        rm -rf "$CONFIG_DIR" || {
            echo "Error: Failed to remove $CONFIG_DIR"
            exit 1
        }
        echo "Removed existing $CONFIG_DIR"
    fi
    mkdir -p "$CONFIG_DIR" || {
        echo "Error: Failed to create $CONFIG_DIR"
        exit 1
    }
    echo "Created fresh $CONFIG_DIR"
}

# Yad dialog
if command -v yad &> /dev/null; then
    yad --title="Reset Hyprland Configuration" \
        --text="This will delete all files in $CONFIG_DIR and create a fresh configuration.\n\nA backup will be created in $BACKUP_DIR.\n\nDo you want to proceed?" \
        --button="Yes:0" \
        --button="No:1" \
        --width=400 --height=200 --center
    response=$?
else
    echo "Warning: yad not found, using terminal prompt"
    read -p "This will delete all files in $CONFIG_DIR and create a fresh configuration. A backup will be created in $BACKUP_DIR. Proceed? (y/N): " response
    case "$response" in
        [yY]*) response=0 ;;
        *) response=1 ;;
    esac
fi

if [[ $response -eq 0 ]]; then
    reset_config
    if [[ -f "$INSTALL_SCRIPT" && -x "$INSTALL_SCRIPT" ]]; then
        read -p "Re-run installation script to set up new configuration? (y/N): " rerun
        if [[ "$rerun" =~ ^[yY] ]]; then
            bash "$INSTALL_SCRIPT" || {
                echo "Error: Failed to run $INSTALL_SCRIPT"
                exit 1
            }
        else
            echo "Configuration reset. Run $INSTALL_SCRIPT manually to set up new configuration."
        fi
    else
        echo "Error: Installation script not found or not executable at $INSTALL_SCRIPT"
        exit 1
    fi
else
    echo "Reset cancelled"
    exit 1
fi'

# Other utility scripts
create_script "$HOME/.config/hypr/scripts/start_geoclue_agent.sh" '#!/usr/bin/env bash
set -euo pipefail
if pgrep -f "geoclue-2.0/demos/agent" > /dev/null; then
    echo "GeoClue agent is already running."
    exit 0
fi
AGENT_PATHS="/usr/libexec/geoclue-2.0/demos/agent /usr/lib/geoclue-2.0/demos/agent"
for path in $AGENT_PATHS; do
    if [ -x "$path" ]; then
        echo "Starting GeoClue agent from: $path"
        "$path" &
        exit 0
    fi
done
echo "GeoClue agent not found."
exit 1' &

create_script "$HOME/.config/hypr/scripts/record.sh" '#!/usr/bin/env bash
set -euo pipefail
getdate() { date "+%Y-%m-%d_%H.%M.%S"; }
getaudiooutput() { pactl list sources | grep "Name" | grep "monitor" | cut -d" " -f2; }
getactivemonitor() { hyprctl monitors -j | jq -r ".[] | select(.focused == true) | .name"; }
xdgvideo="$(xdg-user-dir VIDEOS)"
[[ $xdgvideo = "$HOME" ]] && unset xdgvideo
mkdir -p "${xdgvideo:-$HOME/Videos}"
cd "${xdgvideo:-$HOME/Videos}" || exit
if pgrep wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a "Recorder" & disown
    pkill wf-recorder &
else
    if [[ "$1" == "--fullscreen-sound" ]]; then
        notify-send "Starting recording" "recording_$(getdate).mp4" -a "Recorder" & disown
        wf-recorder -o "$(getactivemonitor)" --pixel-format yuv420p -f "./recording_$(getdate).mp4" -t --audio="$(getaudiooutput)"
    elif [[ "$1" == "--fullscreen" ]]; then
        notify-send "Starting recording" "recording_$(getdate).mp4" -a "Recorder" & disown
        wf-recorder -o "$(getactivemonitor)" --pixel-format yuv420p -f "./recording_$(getdate).mp4" -t
    else
        if ! region="$(slurp 2>&1)"; then
            notify-send "Recording cancelled" "Selection was cancelled" -a "Recorder" & disown
            exit 1
        fi
        notify-send "Starting recording" "recording_$(getdate).mp4" -a "Recorder" & disown
        if [[ "$1" == "--sound" ]]; then
            wf-recorder --pixel-format yuv420p -f "./recording_$(getdate).mp4" -t --geometry "$region" --audio="$(getaudiooutput)"
        else
            wf-recorder --pixel-format yuv420p -f "./recording_$(getdate).mp4" -t --geometry "$region"
        fi
    fi
fi' &

create_script "$HOME/.config/hypr/scripts/zoom.sh" '#!/usr/bin/env bash
set -euo pipefail
get_zoom() { hyprctl getoption -j cursor:zoom_factor | jq -r ".float"; }
clamp() { local val="$1"; awk "BEGIN { v = $val; if (v < 1.0) v = 1.0; if (v > 3.0) v = 3.0; print v; }"; }
set_zoom() { local value="$1"; hyprctl keyword cursor:zoom_factor "$(clamp "$value")"; }
case "$1" in
    reset) set_zoom 1.0 ;;
    increase) [[ -z "$2" ]] && { echo "Usage: $0 increase STEP"; exit 1; }; current=$(get_zoom); new=$(awk "BEGIN { print $current + $2 }"); set_zoom "$new" ;;
    decrease) [[ -z "$2" ]] && { echo "Usage: $0 decrease STEP"; exit 1; }; current=$(get_zoom); new=$(awk "BEGIN { print $current - $2 }"); set_zoom "$new" ;;
    *) echo "Usage: $0 {reset|increase STEP|decrease STEP}"; exit 1 ;;
esac' &

create_script "$HOME/.config/hypr/scripts/workspace_action.sh" '#!/usr/bin/env bash
set -euo pipefail
curr_workspace="$(hyprctl activeworkspace -j | jq -r ".id")"
dispatcher="$1"
shift
if [[ -z "${dispatcher}" || -z "$1" || "${dispatcher}" == "--help" || "${dispatcher}" == "-h" ]]; then
  echo "Usage: $0 <dispatcher> <target>"
  exit 1
fi
if [[ "$1" == *"+"* || "$1" == *"-"* ]]; then
  hyprctl dispatch "${dispatcher}" "$1"
elif [[ "$1" =~ ^[0-9]+$ ]]; then
  target_workspace=$(( ( ( $curr_workspace - 1 ) / 10 ) * 10 + $1 ))
  hyprctl dispatch "${dispatcher}" "${target_workspace}"
else
  hyprctl dispatch "${dispatcher}" "$1"
fi' &

create_script "$HOME/.config/hypr/scripts/launch_first_available.sh" '#!/usr/bin/env bash
set -euo pipefail
for cmd in "$@"; do
    [[ -z "$cmd" ]] && continue
    eval "command -v ${cmd%% *}" >/dev/null 2>&1 || continue
    eval "$cmd" &
    exit
done' &

create_script "$HOME/.config/hypr/scripts/workspace-manager.py" '#!/usr/bin/env python3
import subprocess
import json
import sys
import argparse
def get_workspaces():
    try:
        cmd = "hyprctl workspaces -j"
        result = subprocess.run(cmd.split(), capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting workspaces: {e}")
        return []
    except json.JSONDecodeError as e:
        print(f"Error parsing workspaces: {e}")
        return []
def create_workspace(name):
    try:
        cmd = f"hyprctl dispatch workspace name:{name}"
        subprocess.run(cmd.split(), check=True)
        print(f"Created workspace: {name}")
    except subprocess.CalledProcessError as e:
        print(f"Error creating workspace: {e}")
def list_workspaces():
    workspaces = get_workspaces()
    if not workspaces:
        print("No workspaces found")
        return
    print("Active Workspaces:")
    for ws in workspaces:
        print(f"  {ws['id']}: {ws.get('name', 'Unnamed')} ({ws['windows']} windows)")
def main():
    parser = argparse.ArgumentParser(description="Hyprland Workspace Manager")
    parser.add_argument("action", choices=["list", "create"], help="Action to perform")
    parser.add_argument("--name", help="Workspace name for create action")
    args = parser.parse_args()
    if args.action == "list":
        list_workspaces()
    elif args.action == "create":
        if not args.name:
            print("Error: --name required for create action")
            sys.exit(1)
        create_workspace(args.name)
if __name__ == "__main__":
    main()' &

create_script "$HOME/.config/hypr/scripts/window-manager.sh" '#!/usr/bin/env bash
set -euo pipefail
function tile_windows() {
    hyprctl dispatch layoutmsg "togglesplit"
    echo "Toggled window tiling"
}
function cycle_windows() {
    hyprctl dispatch cyclenext
    echo "Cycled to next window"
}
function smart_resize() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 resize <width> <height>"
        return 1
    fi
    hyprctl dispatch resizeactive "$1" "$2"
    echo "Resized window to $1x$2"
}
function close_all_windows() {
    local count=0
    while hyprctl clients | grep -q "class:"; do
        hyprctl dispatch killactive
        ((count++))
        if [[ $count -gt 50 ]]; then
            echo "Warning: Too many windows, stopping"
            break
        fi
    done
    echo "Closed all windows"
}
function move_to_workspace() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 move <workspace>"
        return 1
    fi
    hyprctl dispatch movetoworkspace "$1"
    echo "Moved window to workspace $1"
}
function toggle_floating() {
    hyprctl dispatch togglefloating
    echo "Toggled floating mode"
}
function maximize_window() {
    hyprctl dispatch fullscreen 1
    echo "Maximized window"
}
case "$1" in
    "tile") tile_windows ;;
    "cycle") cycle_windows ;;
    "resize") smart_resize "$2" "$3" ;;
    "close-all") close_all_windows ;;
    "move") move_to_workspace "$2" ;;
    "float") toggle_floating ;;
    "maximize") maximize_window ;;
    *) 
        echo "Usage: $0 {tile|cycle|resize|close-all|move|float|maximize}"
        echo "  tile - Toggle window tiling"
        echo "  cycle - Cycle to next window"
        echo "  resize <w> <h> - Resize window"
        echo "  close-all - Close all windows"
        echo "  move <ws> - Move to workspace"
        echo "  float - Toggle floating"
        echo "  maximize - Maximize window"
        ;;
esac' &

create_script "$HOME/.config/hypr/scripts/generate-colors.sh" '#!/usr/bin/env bash
set -euo pipefail
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER="$HOME/wallpaper.jpg"
if ! command -v wal &> /dev/null; then
    echo "Error: pywal is not installed. Installing..."
    pipx install pywal || {
        echo "Error: Failed to install pywal"
        exit 1
    }
fi
find_wallpaper() {
    if [[ -f "$DEFAULT_WALLPAPER" ]]; then
        echo "$DEFAULT_WALLPAPER"
    elif [[ -d "$WALLPAPER_DIR" ]] && [[ -n "$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | head -1)" ]]; then
        find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | shuf -n 1
    else
        echo "No wallpaper found. Downloading default wallpaper..."
        wget -O "$DEFAULT_WALLPAPER" "https://raw.githubusercontent.com/hyprwm/hyprland-wallpapers/main/wallpaper.jpg" || {
            echo "Error: Failed to download default wallpaper"
            exit 1
        }
        echo "$DEFAULT_WALLPAPER"
    fi
}
WALLPAPER=$(find_wallpaper)
if [[ ! -f "$WALLPAPER" ]]; then
    echo "Error: Wallpaper not found: $WALLPAPER"
    exit 1
fi
echo "Using wallpaper: $WALLPAPER"
wal -i "$WALLPAPER" -n || {
    echo "Error: Failed to generate colors with pywal"
    exit 1
}
if [[ ! -f "$HOME/.cache/wal/colors.sh" ]]; then
    echo "Error: Failed to generate colors"
    exit 1
fi
source "$HOME/.cache/wal/colors.sh"
cat > "$HOME/.config/hypr/colors.conf" << EOF
# Color scheme generated from wallpaper
general {
    col.active_border = rgba(${color2:1}ee) rgba(${color4:1}ee) 45deg
    col.inactive_border = rgba(${color8:1}aa)
}
misc {
    background_color = rgba(${color0:1}FF)
}
plugin {
    hyprbars {
        bar_text_font = Rubik, Geist, AR One Sans, Reddit Sans, Inter, Roboto, Ubuntu, Noto Sans, sans-serif
        bar_height = 30
        bar_padding = 10
        bar_button_padding = 5
        bar_precedence_over_border = true
        bar_part_of_window = true
        bar_color = rgba(${color0:1}FF)
        col.text = rgba(${color7:1}FF)
        hyprbars-button = rgb(${color7:1}), 13, 󰖭, hyprctl dispatch killactive
        hyprbars-button = rgb(${color7:1}), 13, 󰖯, hyprctl dispatch fullscreen 1
        hyprbars-button = rgb(${color7:1}), 13, 󰖰, hyprctl dispatch movetoworkspacesilent special
    }
}
decoration {
    col.shadow = rgba(${color0:1}ee)
    col.shadow_inactive = rgba(${color8:1}aa)
}
windowrulev2 = bordercolor rgba(${color2:1}AA) rgba(${color2:1}77),pinned:1
EOF
echo "Color scheme updated successfully!"
echo "Reload Hyprland configuration to apply changes: hyprctl reload"
' &

create_script "$HOME/.config/hypr/scripts/wallpaper-manager.sh" '#!/usr/bin/env bash
set -euo pipefail
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER="$HOME/wallpaper.jpg"
URL_REGEX="^(https?|ftp)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$"
mkdir -p "$WALLPAPER_DIR"
set_wallpaper() {
    local wallpaper="$1"
    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: Wallpaper not found: $wallpaper"
        return 1
    fi
    cp "$wallpaper" "$DEFAULT_WALLPAPER"
    if command -v swww &> /dev/null; then
        swww img "$DEFAULT_WALLPAPER" --transition-fps 75 --transition-type wipe
    fi
    if command -v hyprpaper &> /dev/null; then
        hyprpaper &
    fi
    echo "Wallpaper set: $wallpaper"
}
list_wallpapers() {
    echo "Available wallpapers:"
    if [[ -d "$WALLPAPER_DIR" ]]; then
        find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | nl
    else
        echo "No wallpaper directory found at $WALLPAPER_DIR"
    fi
}
download_wallpaper() {
    local url="$1"
    local filename=$(basename "$url")
    local filepath=$(mktemp "$WALLPAPER_DIR/tmp.XXXXXX.$filename")
    if [[ -z "$url" ]]; then
        echo "Usage: $0 download <url>"
        return 1
    fi
    if ! [[ "$url" =~ $URL_REGEX ]]; then
        echo "Error: Invalid URL: $url"
        return 1
    fi
    if ! curl --head --silent --fail "$url" > /dev/null; then
        echo "Error: URL is not accessible: $url"
        return 1
    fi
    echo "Downloading wallpaper from $url..."
    if wget -O "$filepath" "$url"; then
        echo "Downloaded: $filepath"
        set_wallpaper "$filepath"
    else
        echo "Error: Failed to download wallpaper"
        rm -f "$filepath"
        return 1
    fi
}
case "$1" in
    "set") [[ $# -ne 2 ]] && { echo "Usage: $0 set <wallpaper_path>"; exit 1; }; set_wallpaper "$2" ;;
    "list") list_wallpapers ;;
    "download") [[ $# -ne 2 ]] && { echo "Usage: $0 download <url>"; exit 1; }; download_wallpaper "$2" ;;
    "random") 
        random_wallpaper=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | shuf -n 1)
        [[ -n "$random_wallpaper" ]] && set_wallpaper "$random_wallpaper" || echo "No wallpapers found in $WALLPAPER_DIR"
        ;;
    *) 
        echo "Usage: $0 {set|list|download|random}"
        echo "  set <path> - Set wallpaper from file"
        echo "  list - List available wallpapers"
        echo "  download <url> - Download and set wallpaper"
        echo "  random - Set random wallpaper"
        ;;
esac' &

create_script "$HOME/.config/hypr/scripts/close-all-windows.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "Closing all windows..."
window_count=$(hyprctl clients | grep -c "class:" || echo "0")
if [[ $window_count -eq 0 ]]; then
    echo "No windows to close"
    exit 0
fi
echo "Found $window_count windows"
count=0
while hyprctl clients | grep -q "class:"; do
    hyprctl dispatch killactive
    ((count++))
    if [[ $count -gt 50 ]]; then
        echo "Warning: Too many windows, stopping"
        break
    fi
done
echo "Closed $count windows"' &

create_script "$HOME/.config/hypr/scripts/toggle-blur.sh" '#!/usr/bin/env bash
set -euo pipefail
current_state=$(hyprctl getoption decoration:blur:enabled | grep -o "int: [01]" | cut -d" " -f2)
if [[ "$current_state" == "1" ]]; then
    hyprctl keyword decoration:blur:enabled false
    echo "Blur disabled"
else
    hyprctl keyword decoration:blur:enabled true
    echo "Blur enabled"
fi' &

create_script "$HOME/.config/hypr/scripts/toggle-opacity.sh" '#!/usr/bin/env bash
set -euo pipefail
current_active=$(hyprctl getoption decoration:active_opacity | grep -o "float: [0-9.]*" | cut -d" " -f2)
if (( $(echo "$current_active < 1.0" | bc -l) )); then
    hyprctl keyword decoration:active_opacity 1.0
    hyprctl keyword decoration:inactive_opacity 1.0
    echo "Windows made opaque"
else
    hyprctl keyword decoration:active_opacity 0.95
    hyprctl keyword decoration:inactive_opacity 0.85
    echo "Windows made transparent"
fi' &

create_script "$HOME/.config/hypr/scripts/sleep.sh" '#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    "suspend") echo "Suspending system..."; systemctl suspend ;;
    "hibernate") echo "Hibernating system..."; systemctl hibernate ;;
    "lock") echo "Locking screen..."; hyprlock ;;
    *) echo "Usage: $0 {suspend|hibernate|lock}" ;;
esac' &

create_script "$HOME/.config/hypr/scripts/system-status.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "=== Hyprland System Status ==="
echo
echo "Hyprland Version:"
hyprctl version | head -1
echo
echo "Active Windows:"
hyprctl clients | grep -c "class:" || echo "0"
echo
echo "Workspaces:"
hyprctl workspaces | grep -E "workspace [0-9]+" | wc -l
echo
echo "Monitors:"
hyprctl monitors | grep -c "Monitor" || echo "0"
echo
echo "Memory Usage:"
free -h | grep "Mem:"
echo
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk "{print $2}" | cut -d"%" -f1
echo
echo "Disk Usage:"
df -h / | tail -1
echo
echo "GPU Drivers:"
for driver in mesa nvidia amdvlk; do
    if pacman -Qi "$driver" &> /dev/null; then
        echo "✅ $driver is installed"
    else
        echo "⚠️ $driver is not installed"
    fi
done
echo
echo "=== Status Complete ==="' &

create_script "$HOME/.config/hypr/scripts/restore-backup.sh" '#!/usr/bin/env bash
set -euo pipefail
if [[ -z "$1" ]]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi
if [[ -d "$1" ]]; then
    cp -r "$1/"* "$HOME/.config/hypr/" || {
        echo "Error: Failed to restore backup from $1"
        exit 1
    }
    echo "Restored backup from $1"
else
    echo "Backup directory not found: $1"
    exit 1
fi' &

create_script "$HOME/.config/hypr/scripts/validate-config.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "=== Hyprland Configuration Validation ==="
echo
if ! pgrep -x "Hyprland" > /dev/null; then
    echo "❌ Hyprland is not running"
    echo "   Please start Hyprland first"
    exit 1
else
    echo "✅ Hyprland is running"
fi
config_files=(
    "$HOME/.config/hypr/general.conf"
    "$HOME/.config/hypr/colors.conf"
    "$HOME/.config/hypr/rules.conf"
    "$HOME/.config/hypr/keybinds.conf"
    "$HOME/.config/hypr/hypridle.conf"
    "$HOME/.config/hypr/hyprlock.conf"
    "$HOME/.config/hypr/hyprpaper.conf"
    "$HOME/.config/hypr/env.conf"
    "$HOME/.config/hypr/execs.conf"
)
for config in "${config_files[@]}"; do
    if [[ -f "$config" ]]; then
        echo "✅ $config exists"
    else
        echo "❌ $config missing"
    fi
done
echo
echo "Validating source directives in general.conf..."
source_lines=$(grep "^source =" "$HOME/.config/hypr/general.conf" || true)
while IFS= read -r line; do
    file=$(echo "$line" | cut -d"=" -f2 | xargs)
    file_expanded=$(eval echo "$file")
    if [[ -f "$file_expanded" ]]; then
        echo "✅ Source file exists: $file_expanded"
    else
        echo "❌ Source file missing: $file_expanded"
    fi
done <<< "$source_lines"
echo
echo "Validating configuration syntax..."
if hyprctl reload 2>&1 | grep -q "error"; then
    echo "❌ Configuration has syntax errors"
    hyprctl reload
else
    echo "✅ Configuration syntax is valid"
fi
echo
echo "Checking required packages..."
required_packages=(
    "hyprland" "hypridle" "hyprlock" "mako" "swww" "wl-clipboard"
    "cliphist" "fuzzel" "foot" "jq" "wf-recorder" "slurp" "libnotify" "fcitx5"
    "cmake" "meson" "cpio" "pkg-config" "git" "gcc" "g++"
)
for package in "${required_packages[@]}"; do
    if pacman -Qi "$package" &> /dev/null; then
        echo "✅ $package is installed"
    else
        echo "❌ $package is not installed"
    fi
done
echo
echo "Checking GPU drivers..."
for driver in mesa nvidia amdvlk; do
    if pacman -Qi "$driver" &> /dev/null; then
        echo "✅ $driver is installed"
    else
        echo "⚠️ $driver is not installed"
    fi
done
echo
echo "Checking utility scripts..."
script_dir="$HOME/.config/hypr/scripts"
if [[ -d "$script_dir" ]]; then
    script_count=$(find "$script_dir" -name "*.sh" -o -name "*.py" | wc -l)
    echo "✅ Found $script_count utility scripts"
else
    echo "❌ Scripts directory not found"
fi
echo
echo "=== Validation Complete ==="' &

create_script "$HOME/.config/hypr/scripts/maintenance.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "=== Hyprland System Maintenance ==="
echo
echo "Cleaning up logs..."
if [[ -d "$HOME/.cache/hyprland" ]]; then
    find "$HOME/.cache/hyprland" -name "*.log" -mtime +7 -delete
    echo "✅ Cleaned old Hyprland logs"
fi
echo "Cleaning up wallpaper cache..."
if [[ -d "$HOME/.cache/wal" ]]; then
    find "$HOME/.cache/wal" -name "*.jpg" -mtime +30 -delete
    echo "✅ Cleaned old wallpaper cache"
fi
echo "Updating package database..."
yay -Sy &> /dev/null || {
    echo "Error: Failed to sync package database"
    exit 1
}
echo "✅ Package database updated"
echo "Checking for package updates..."
updates=$(yay -Qu | wc -l)
if [[ $updates -gt 0 ]]; then
    echo "⚠️  $updates packages have updates available"
    echo "   Run 'yay -Syu' to update"
else
    echo "✅ All packages are up to date"
fi
echo "Checking for plugin updates..."
if command -v hyprpm &> /dev/null; then
    hyprpm update || {
        echo "Error: Failed to update Hyprland plugins"
        exit 1
    }
    echo "✅ Hyprland plugins updated"
else
    echo "⚠️ hyprpm not found, skipping plugin update"
fi
echo
echo "Checking disk usage..."
disk_usage=$(df -h / | awk "NR==2 {print $5}" | sed "s/%//")
if [[ $disk_usage -gt 80 ]]; then
    echo "⚠️  Disk usage is high: ${disk_usage}%"
else
    echo "✅ Disk usage is normal: ${disk_usage}%"
fi
echo
echo "=== Maintenance Complete ==="' &

create_script "$HOME/.config/hypr/scripts/launch_polkit.sh" '#!/usr/bin/env bash
set -euo pipefail
POLKIT_AGENTS=(
    "/usr/lib/polkit-kde-authentication-agent-1"
    "/usr/libexec/polkit-kde-authentication-agent-1"
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    "/usr/libexec/polkit-gnome/polkit-gnome-authentication-agent-1"
)
if pgrep -f "polkit-.*-authentication-agent" > /dev/null; then
    echo "Polkit agent is already running."
    exit 0
fi
for agent in "${POLKIT_AGENTS[@]}"; do
    if [[ -x "$agent" ]]; then
        echo "Starting polkit agent: $agent"
        "$agent" &
        exit 0
    fi
done
echo "No polkit agent found. Installing polkit-gnome as fallback..."
yay -S --needed polkit-gnome || {
    echo "Error: Failed to install polkit-gnome"
    exit 1
}
if [[ -x "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1" ]]; then
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
    echo "Started polkit-gnome agent"
else
    echo "Error: No polkit agent could be started"
    exit 1
fi' &

create_script "$HOME/.config/hypr/scripts/advanced-features.sh" '#!/usr/bin/env bash
set -euo pipefail

# Advanced Hyprland Features Manager
# This script provides additional functionality from hyprland-advanced-extras.sh

log_info() {
    echo -e "$(date "+%Y-%m-%d %H:%M:%S") [INFO] $1"
}

log_success() {
    echo -e "$(date "+%Y-%m-%d %H:%M:%S") [SUCCESS] $1"
}

log_error() {
    echo -e "$(date "+%Y-%m-%d %H:%M:%S") [ERROR] $1"
}

# Enhanced workspace management with dynamic creation
create_dynamic_workspace() {
    local workspace_name="$1"
    local workspace_id="$2"
    
    if [[ -z "$workspace_name" || -z "$workspace_id" ]]; then
        echo "Usage: $0 create-workspace <name> <id>"
        return 1
    fi
    
    log_info "Creating dynamic workspace: $workspace_name (ID: $workspace_id)"
    hyprctl dispatch workspace "$workspace_id"
    hyprctl dispatch renameworkspace "$workspace_id" "$workspace_name"
    log_success "Workspace $workspace_name created successfully"
}

# Advanced window management with smart tiling
smart_tile_windows() {
    local direction="$1"
    
    case "$direction" in
        "horizontal"|"h")
            hyprctl dispatch layoutmsg "togglesplit"
            log_info "Toggled horizontal split"
            ;;
        "vertical"|"v")
            hyprctl dispatch layoutmsg "togglesplit"
            log_info "Toggled vertical split"
            ;;
        "master"|"m")
            hyprctl dispatch layoutmsg "cyclenext"
            log_info "Cycled to next layout"
            ;;
        *)
            echo "Usage: $0 smart-tile {horizontal|vertical|master}"
            return 1
            ;;
    esac
}

# Dynamic color scheme application
apply_dynamic_colors() {
    local wallpaper_path="$1"
    
    if [[ -z "$wallpaper_path" ]]; then
        wallpaper_path="$HOME/wallpaper.jpg"
    fi
    
    if [[ ! -f "$wallpaper_path" ]]; then
        log_error "Wallpaper not found: $wallpaper_path"
        return 1
    fi
    
    log_info "Applying dynamic colors from: $wallpaper_path"
    
    if command -v wal &> /dev/null; then
        wal -i "$wallpaper_path" -n
        log_success "Dynamic colors applied successfully"
    else
        log_error "pywal not found. Install with: pipx install pywal"
        return 1
    fi
}

# Advanced gesture configuration
configure_gestures() {
    log_info "Configuring advanced gestures..."
    
    # Enable workspace swipe gestures
    hyprctl keyword "gestures:workspace_swipe" true
    hyprctl keyword "gestures:workspace_swipe_fingers" 3
    hyprctl keyword "gestures:workspace_swipe_distance" 300
    hyprctl keyword "gestures:workspace_swipe_invert" true
    hyprctl keyword "gestures:workspace_swipe_min_speed_to_force" 30
    hyprctl keyword "gestures:workspace_swipe_cancel_ratio" 0.5
    hyprctl keyword "gestures:workspace_swipe_create_new" true
    hyprctl keyword "gestures:workspace_swipe_forever" true
    
    log_success "Advanced gestures configured"
}

# Enhanced blur effects
configure_blur() {
    local intensity="$1"
    
    if [[ -z "$intensity" ]]; then
        intensity="5"
    fi
    
    log_info "Configuring blur effects with intensity: $intensity"
    
    hyprctl keyword "decoration:blur:enabled" true
    hyprctl keyword "decoration:blur:size" "$intensity"
    hyprctl keyword "decoration:blur:passes" 3
    hyprctl keyword "decoration:blur:new_optimizations" true
    hyprctl keyword "decoration:blur:xray" true
    hyprctl keyword "decoration:blur:ignore_opacity" true
    
    log_success "Blur effects configured"
}

# Advanced window rules management
manage_window_rules() {
    local action="$1"
    local rule="$2"
    
    case "$action" in
        "add")
            if [[ -z "$rule" ]]; then
                echo "Usage: $0 manage-rules add \"<rule>\""
                return 1
            fi
            hyprctl keyword "windowrule" "$rule"
            log_success "Added window rule: $rule"
            ;;
        "list")
            hyprctl getoption "windowrule" | grep -v "int:"
            ;;
        "clear")
            hyprctl keyword "windowrule" "reset"
            log_success "Cleared all window rules"
            ;;
        *)
            echo "Usage: $0 manage-rules {add|list|clear} [rule]"
            return 1
            ;;
    esac
}

# System performance monitoring
monitor_performance() {
    log_info "Hyprland Performance Monitor"
    echo "================================"
    
    echo "Active Windows: $(hyprctl clients | grep -c "class:" || echo "0")"
    echo "Workspaces: $(hyprctl workspaces | grep -c "workspace" || echo "0")"
    echo "Monitors: $(hyprctl monitors | grep -c "Monitor" || echo "0")"
    
    echo
    echo "Memory Usage:"
    free -h | grep "Mem:"
    
    echo
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%" -f1
    
    echo
    echo "GPU Status:"
    for driver in mesa nvidia amdvlk; do
        if pacman -Qi "$driver" &> /dev/null; then
            echo "✅ $driver is installed"
        else
            echo "❌ $driver is not installed"
        fi
    done
}

# Main function
main() {
    case "$1" in
        "create-workspace")
            create_dynamic_workspace "$2" "$3"
            ;;
        "smart-tile")
            smart_tile_windows "$2"
            ;;
        "apply-colors")
            apply_dynamic_colors "$2"
            ;;
        "configure-gestures")
            configure_gestures
            ;;
        "configure-blur")
            configure_blur "$2"
            ;;
        "manage-rules")
            manage_window_rules "$2" "$3"
            ;;
        "monitor")
            monitor_performance
            ;;
        *)
            echo "Advanced Hyprland Features Manager"
            echo "=================================="
            echo
            echo "Usage: $0 {command} [options]"
            echo
            echo "Commands:"
            echo "  create-workspace <name> <id>  - Create dynamic workspace"
            echo "  smart-tile {h|v|m}            - Smart window tiling"
            echo "  apply-colors [wallpaper]      - Apply dynamic colors"
            echo "  configure-gestures            - Configure advanced gestures"
            echo "  configure-blur [intensity]    - Configure blur effects"
            echo "  manage-rules {add|list|clear} - Manage window rules"
            echo "  monitor                       - Monitor system performance"
            echo
            echo "Examples:"
            echo "  $0 create-workspace \"PROJECT\" 6"
            echo "  $0 smart-tile horizontal"
            echo "  $0 apply-colors ~/Pictures/wallpaper.jpg"
            echo "  $0 configure-blur 8"
            echo "  $0 manage-rules add \"float,class:^(pavucontrol)$\""
            echo "  $0 monitor"
            ;;
    esac
}

main "$@"' &

create_script "$HOME/.config/hypr/README.md" '# Hyprland Advanced Configuration

This directory contains an enhanced Hyprland configuration with advanced features and utilities.

## Configuration Files
- `general.conf` - Main configuration, sources other configs
- `colors.conf` - Color scheme configuration
- `rules.conf` - Window and layer rules
- `keybinds.conf` - Keybindings configuration
- `hypridle.conf` - Idle daemon configuration
- `hyprlock.conf` - Screen lock configuration
- `hyprpaper.conf` - Wallpaper configuration
- `env.conf` - Environment variables
- `execs.conf` - Startup commands
- `~/.config/fcitx5/config` - Input method configuration

## Utility Scripts
### Window Management
- `window-manager.sh` - Advanced window management functions
- `close-all-windows.sh` - Close all windows safely
- `restore-backup.sh` - Restore configuration from backup
- `reset-hyprland.sh` - Reset configuration with backup and fresh start

### Workspace Management
- `workspace-manager.py` - Python-based workspace management
- `system-status.sh` - System status monitoring
- `workspace_action.sh` - Workspace navigation
- `launch_first_available.sh` - Launch first available command

### Visual Effects
- `toggle-blur.sh` - Toggle blur effects
- `toggle-opacity.sh` - Toggle window opacity
- `generate-colors.sh` - Generate color schemes from wallpapers

### Wallpaper Management
- `wallpaper-manager.sh` - Wallpaper management and downloading

### System Management
- `sleep.sh` - Power management functions
- `maintenance.sh` - System maintenance tasks
- `validate-config.sh` - Configuration validation
- `launch_polkit.sh` - Polkit agent launcher
- `advanced-features.sh` - Advanced features manager with dynamic workspace creation, smart tiling, and performance monitoring

## Keybindings
- `Super + Q` - Close active window
- `Super + Shift + Q` - Close all windows
- `Super + F` - Toggle fullscreen
- `Super + V` - Toggle floating
- `Super + B` - Toggle blur
- `Super + O` - Toggle opacity
- `Super + W` - Wallpaper manager
- `Super + Shift + W` - Generate colors
- `Super + L` - Lock screen
- `Super + Shift + L` - Suspend
- `Super + Ctrl + L` - Power off
- `Super + Shift + R` - Reset configuration

## Installation
```bash
chmod +x hyprland-advanced-extras-enhanced.sh
./hyprland-advanced-extras-enhanced.sh
```

## Prerequisites
- **Core Dependencies**: `yay`, `pip`, `pipx`, `yad`
- **hyprpm Dependencies**: `cmake`, `meson`, `cpio`, `pkg-config`, `git`, `gcc`, `g++`
- **Essential Packages**: `hyprland`, `hypridle`, `hyprlock`, `mako`, `swww`, `wl-clipboard`, `cliphist`, `fuzzel`, `foot`, `jq`, `wf-recorder`, `slurp`, `libnotify`, `fcitx5`
- **Recommended**: GPU drivers (`mesa`, `nvidia`, or `amdvlk`)

## Reset Configuration
To reset the Hyprland configuration and start fresh:
```bash
~/.config/hypr/scripts/reset-hyprland.sh
```
This will back up the current configuration, delete the existing `~/.config/hypr/` directory, create a fresh one, and optionally re-run the installation script.

## Validation
Validate the configuration:
```bash
~/.config/hypr/scripts/validate-config.sh
```

## Backup Restoration
Restore a previous configuration:
```bash
~/.config/hypr/scripts/restore-backup.sh <backup_directory>
```

## Maintenance
Run periodic maintenance:
```bash
~/.config/hypr/scripts/maintenance.sh
```

## Features
- Advanced window management with gestures and smart tiling
- Dynamic color schemes from wallpapers with pywal integration
- Comprehensive window rules and layer effects
- Enhanced animations and visual effects with advanced blur
- Power management with systemd services
- System monitoring with GPU driver checks and performance monitoring
- Wallpaper management and downloading with dynamic transitions
- Plugin management with hyprpm
- Input method support with fcitx5
- Reset functionality with backup and fresh start
- Advanced gesture configuration with workspace swipes
- Dynamic workspace creation and management
- Enhanced touchpad support with gesture binds
- Waybar modules for pacman updates and weather
- Hyperpaper integration for advanced wallpaper management

## Troubleshooting
If issues occur:
1. Run `~/.config/hypr/scripts/validate-config.sh` to check configuration and dependencies.
2. Check logs: `journalctl --user -u Hyprland`
3. Check installation logs: `~/.cache/hyprland/install.log`
4. Test configuration: `hyprctl reload`
5. Check system status: `~/.config/hypr/scripts/system-status.sh`
6. Ensure GPU drivers are installed (`mesa`, `nvidia`, or `amdvlk`).
7. Verify `hyprpm` dependencies: `cmake`, `meson`, `cpio`, `pkg-config`, `git`, `gcc`, `g++`.
8. If package installation fails, check your internet connection and try running `yay -Sy` first.
9. For terminal issues, ensure you have a compatible terminal emulator installed (foot, kitty, alacritty, etc.).

## Support
For additional help, check the Hyprland documentation or community forums.' &
