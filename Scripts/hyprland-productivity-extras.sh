#!/usr/bin/env bash

# Install productivity enhancements
yay -S --needed \
    ydotool \
    wtype \
    hyprlang \
    hyprdock \
    hyprsome \
    nwg-bar \
    wayprompt \
    hyprcursor-git \
    hyprctl-git \
    xdg-desktop-portal-hyprland-git \
    swayosd-git \
    eww-tray-wayland-git \
    wev \
    grim \
    satty \
    hyprprop

# Create advanced macro system
mkdir -p ~/.config/hypr/macros
cat << 'EEOF' > ~/.config/hypr/macros/macro-system.conf
bind = SUPER, 1, exec, ~/.config/hypr/macros/workspace-layout-1.sh
bind = SUPER, 2, exec, ~/.config/hypr/macros/workspace-layout-2.sh
bind = SUPER, 3, exec, ~/.config/hypr/macros/workspace-layout-3.sh
bind = SUPER SHIFT, D, exec, ~/.config/hypr/macros/development-environment.sh
bind = SUPER SHIFT, M, exec, ~/.config/hypr/macros/media-environment.sh
bind = SUPER SHIFT, W, exec, ~/.config/hypr/macros/work-environment.sh
EEOF

# Create custom workspace layouts
cat << 'EEOF' > ~/.config/hypr/macros/workspace-layout-1.sh
#!/usr/bin/env bash
hyprctl dispatch workspace 1
kitty --class=dev-term &
sleep 0.5
firefox --class=dev-browser &
sleep 0.5
code --class=dev-ide &
sleep 0.5
hyprctl dispatch layoutmsg "preselect 2"
EEOF
chmod +x ~/.config/hypr/macros/workspace-layout-1.sh

# Create advanced window groups
cat << 'EEOF' > ~/.config/hypr/groups.conf
windowrule = group set,^(Firefox)$
windowrule = group set,^(code-oss)$
windowrule = group set,^(kitty)$
windowrule = group set,^(thunar)$

bind = SUPER, tab, changegroupactive, f
bind = SUPER SHIFT, tab, changegroupactive, b
EEOF

# Create advanced gesture configuration
cat << 'EEOF' > ~/.config/hypr/gestures.conf
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
    workspace_swipe_create_new = true
    workspace_swipe_direction_lock = true
    workspace_swipe_direction_lock_threshold = 10
    workspace_swipe_forever = true
    workspace_swipe_numbered = true
    workspace_swipe_use_r = true
}
EEOF

# Create advanced window rules
cat << 'EEOF' > ~/.config/hypr/window-rules-advanced.conf
# Smart window placement
windowrulev2 = float, class:^(pavucontrol)$
windowrulev2 = float, title:^(Picture-in-Picture)$
windowrulev2 = float, class:^(blueman-manager)$
windowrulev2 = float, class:^(org.kde.polkit-kde-authentication-agent-1)$
windowrulev2 = idleinhibit focus, class:^(mpv)$
windowrulev2 = idleinhibit fullscreen, class:^(firefox)$

# Workspace assignments
windowrulev2 = workspace 1, class:^(kitty)$
windowrulev2 = workspace 2 silent, class:^(firefox)$
windowrulev2 = workspace 3 silent, class:^(discord)$
windowrulev2 = workspace 4 silent, class:^(spotify)$

# Size rules
windowrulev2 = size 800 600, class:^(pavucontrol)$
windowrulev2 = maxsize 1200 800, class:^(pavucontrol)$
windowrulev2 = minsize 400 300, class:^(pavucontrol)$

# Position rules
windowrulev2 = center, class:^(pavucontrol)$
windowrulev2 = center, class:^(blueman-manager)$

# Animation rules
windowrulev2 = animation slide, class:^(wofi)$
windowrulev2 = animation popin, class:^(notification)$
EEOF

# Create productivity keybindings
cat << 'EEOF' > ~/.config/hypr/keybinds-productivity.conf
# Productivity bindings
bind = SUPER, Return, exec, kitty
bind = SUPER SHIFT, Q, killactive,
bind = SUPER SHIFT, E, exit,
bind = SUPER, V, togglefloating,
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,
bind = SUPER, F, fullscreen,
bind = SUPER SHIFT, F, fakefullscreen,

# Group management
bind = SUPER SHIFT, G, togglegroup,
bind = SUPER, G, lockgroups, toggle
bind = ALT, tab, cyclenext,
bind = ALT SHIFT, tab, cyclenext, prev

# Advanced window movement
bind = SUPER SHIFT, left, movewindow, l
bind = SUPER SHIFT, right, movewindow, r
bind = SUPER SHIFT, up, movewindow, u
bind = SUPER SHIFT, down, movewindow, d

# Advanced workspace movement
bind = SUPER ALT, left, workspace, -1
bind = SUPER ALT, right, workspace, +1
bind = SUPER ALT, up, workspace, -5
bind = SUPER ALT, down, workspace, +5
EEOF

# Create system monitoring script
cat << 'EEOF' > ~/.config/hypr/scripts/system-monitor.sh
#!/usr/bin/env bash

while true; do
    # CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # Memory usage
    mem_usage=$(free | grep Mem | awk '{print ($3/$2) * 100}')
    
    # GPU usage (if nvidia-smi is available)
    if command -v nvidia-smi &> /dev/null; then
        gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
    else
        gpu_usage="N/A"
    fi
    
    # Temperature
    temp=$(sensors | grep "CPU" | awk '{print $2}' | tr -d '+°C')
    
    # Create notification
    notify-send "System Monitor" "CPU: ${cpu_usage}%\nMemory: ${mem_usage}%\nGPU: ${gpu_usage}\nTemp: ${temp}°C" -t 5000
    
    sleep 30
done
EEOF
chmod +x ~/.config/hypr/scripts/system-monitor.sh

echo -e "\n\033[0;32mProductivity enhancements installation completed! 🚀\033[0m"
echo -e "\033[0;34mNew features added:\033[0m"
echo "• Advanced macro system for quick workspace layouts"
echo "• Smart window grouping with visual indicators"
echo "• Enhanced gesture controls"
echo "• Advanced window rules and animations"
echo "• Productivity-focused keybindings"
echo "• Real-time system monitoring"
echo -e "\n\033[0;33mTo activate:\033[0m"
echo "1. Start system monitoring: ~/.config/hypr/scripts/system-monitor.sh &"
echo "2. Apply new configurations: hyprctl reload"
echo "3. Use SUPER + [1-3] for quick workspace layouts"
echo "4. Use SUPER + SHIFT + [D/M/W] for environment presets"
