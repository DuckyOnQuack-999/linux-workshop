#!/usr/bin/env bash

# Install additional packages for enhanced functionality
yay -S --needed \
    pywal-git \
    hyprpaper \
    eww-wayland \
    foot \
    fuzzel \
    playerctl \
    wlsunset \
    hyprcursor \
    hyprkeys \
    hyprshot \
    waybar-module-pacman-updates-git \
    waybar-module-weather-git \
    swaync \
    swayosd \
    hyprnome \
    wluma \
    hyprdim \
    xdg-desktop-portal-hyprland-git \
    gtklock \
    gtklock-powerbar-module \
    gtklock-userinfo-module \
    wob \
    hyperpaper \
    pyprland
a
# Create enhanced Hyprland configuration
cat << 'EEOF' > ~/.config/hypr/hyprland.conf
# Source additional config files
source = ~/.config/hypr/colors.conf
source = ~/.config/hypr/windowrules.conf
source = ~/.config/hypr/keybinds.conf

# Monitor configuration with adaptive refresh rate
monitor = ,preferred,auto,auto
monitor = ,highrr,auto,1

# Enhanced animations and effects
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

# Advanced decoration settings
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
    follow_mouse = 2
    natural_scroll = true
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
        disable_while_typing = true
        middle_button_emulation = true
        tap-and-drag = true
    }
    sensitivity = 0
    accel_profile = flat
}

# Advanced gestures
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
    workspace_swipe_create_new = true
    workspace_swipe_forever = true
}

# Enhanced general settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(ff92a6ee) rgba(94bfd1ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
    allow_tearing = false
    cursor_inactive_timeout = 5
}

# Advanced dwindle layout settings
dwindle {
    pseudotile = true
    preserve_split = true
    special_scale_factor = 0.8
    split_width_multiplier = 1.0
    no_gaps_when_only = false
    use_active_for_splits = true
    force_split = 2
}

# Master layout settings
master {
    new_is_master = true
    new_on_top = true
    mfact = 0.5
    special_scale_factor = 0.8
    no_gaps_when_only = false
}

# Touchpad gesture binds
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
bindm = SUPER ALT, mouse:272, resizewindow

# Dynamic window rules
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

# Dynamic workspace configuration
workspace = 1, name:DEV, default:true, persistent:true, border_size:3
workspace = 2, name:WWW, default:true, persistent:true
workspace = 3, name:CHAT, default:true, persistent:true
workspace = 4, name:MUSIC, default:true, persistent:true
workspace = 5, name:GAMES, default:true, persistent:true
workspace = special:scratchpad, on-created-empty:kitty

# Environment variables
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland
env = QT_QPA_PLATFORMTHEME,qt5ct
env = MOZ_ENABLE_WAYLAND,1
env = WLR_NO_HARDWARE_CURSORS,1

# Startup applications with fancy notification
exec-once = swww init && swww img ~/wallpaper.jpg --transition-fps 75 --transition-type wipe
exec-once = waybar & mako & nm-applet --indicator & blueman-applet
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = wl-paste --watch cliphist store
exec-once = swayosd-server
exec-once = hypridle
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = ~/.config/hypr/scripts/sleep.sh
exec-once = wluma
exec-once = pypr
EEOF

# Create enhanced workspace management script
mkdir -p ~/.config/hypr/scripts
cat << 'EEOF' > ~/.config/hypr/scripts/workspace-manager.py
#!/usr/bin/env python3
import subprocess
import json

def get_workspaces():
    cmd = "hyprctl workspaces -j"
    result = subprocess.run(cmd.split(), capture_output=True, text=True)
    return json.loads(result.stdout)

def create_workspace(name):
    cmd = f"hyprctl dispatch workspace name:{name}"
    subprocess.run(cmd.split())

def main():
    workspaces = get_workspaces()
    # Add your custom workspace management logic here
    pass

if __name__ == "__main__":
    main()
EEOF
chmod +x ~/.config/hypr/scripts/workspace-manager.py

# Create advanced window management script
cat << 'EEOF' > ~/.config/hypr/scripts/window-manager.sh
#!/usr/bin/env bash

# Window management functions
function tile_windows() {
    hyprctl dispatch layoutmsg "togglesplit"
}

function cycle_windows() {
    hyprctl dispatch cyclenext
}

function smart_resize() {
    hyprctl dispatch resizeactive "$1" "$2"
}

# Main logic
case "$1" in
    "tile") tile_windows ;;
    "cycle") cycle_windows ;;
    "resize") smart_resize "$2" "$3" ;;
    *) echo "Usage: $0 {tile|cycle|resize <width> <height>}" ;;
esac
EEOF
chmod +x ~/.config/hypr/scripts/window-manager.sh

# Create custom keybindings configuration
cat << 'EEOF' > ~/.config/hypr/keybinds.conf
$mainMod = SUPER

# Advanced window management
bind = $mainMod, Q, killactive,
bind = $mainMod cat << 'EEOF' > ~/.config/hypr/scripts/generate-colors.sh
#!/usr/bin/env bash

# Generate color scheme from wallpaper
wal -i ~/wallpaper.jpg

# Update Hyprland colors
source ~/.cache/wal/colors.sh

cat > ~/.config/hypr/colors.conf << EOF
general {
    col.active_border = rgba(${color2:1}ee) rgba(${color4:1}ee) 45deg
    col.inactive_border = rgba(${color8:1}aa)
}

decoration {
    col.shadow = rgba(${color0:1}ee)
    col.shadow_inactive = rgba(${color8:1}aa)
}
SHIFT, Q, exec, ~/.config/hypr/scripts/close-all-windows.sh
bind = $mainMod, F, fullscreen, 1
bind = $mainMod SHIFT, F, fullscreen, 0
bind = $mainMod, V, togglefloating,
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Advanced workspace management
bind = $mainMod SHIFT, right, movetoworkspace, +1
bind = $mainMod SHIFT, left, movetoworkspace, -1
bind = $mainMod CTRL, right, workspace, +1
bind = $mainMod CTRL, left, workspace, -1
bind = $mainMod ALT, up, movetoworkspace, special:scratchpad
bind = $mainMod ALT, down, togglespecialworkspace, scratchpad

# Media controls with visual feedback
bind = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise
bind = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower
bind = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
bind = , XF86MonBrightnessUp, exec, swayosd-client --brightness raise
bind = , XF86MonBrightnessDown, exec, swayosd-client --brightness lower

# Screenshot utilities
bind = , Print, exec, hyprshot -m output --clipboard-only
bind = SHIFT, Print, exec, hyprshot -m region --clipboard-only
bind = CTRL, Print, exec, hyprshot -m window --clipboard-only

# Quick settings
bind = $mainMod, B, exec, ~/.config/hypr/scripts/toggle-blur.sh
bind = $mainMod, O, exec, ~/.config/hypr/scripts/toggle-opacity.sh
bind = $mainMod SHIFT, N, exec, swaync-client -t
EEOF

# Install pywal for dynamic colors
pip install pywal

# Create color scheme generator script
cat << 'EEOF' > ~/.config/hypr/scripts/generate-colors.sh
#!/usr/bin/env bash

# Generate color scheme from wallpaper
wal -i ~/wallpaper.jpg

# Update Hyprland colors 
source ~/.cache/wal/colors.sh

cat > ~/.config/hypr/colors.conf << EOF
general {
    col.active_border = rgba(${color2:1}ee) rgba(${color4:1}ee) 45deg
    col.inactive_border = rgba(${color8:1}aa)
}

decoration {
    col.shadow = rgba(${color0:1}ee)
    col.shadow_inactive = rgba(${color8:1}aa)
}
EEOF
