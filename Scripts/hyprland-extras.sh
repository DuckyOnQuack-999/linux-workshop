#!/usr/bin/env bash

# Install additional packages
yay -S --needed \
    eww-wayland \
    swayidle \
    swaylock-effects \
    wlogout \
    grim \
    slurp \
    grimblast-git \
    wl-clipboard \
    cliphist \
    imagemagick \
    playerctl \
    wev \
    hypridle \
    hyprlock \
    swappy \
    wf-recorder \
    libnotify

# Create power menu script
mkdir -p ~/.config/wlogout
cat << 'EEOF' > ~/.config/wlogout/style.css
* {
    background-image: none;
    font-family: "JetBrainsMono Nerd Font";
}

window {
    background-color: rgba(17, 17, 27, 0.85);
}

button {
    color: #cdd6f4;
    background-color: #1e1e2e;
    border-style: solid;
    border-width: 2px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
    border-radius: 10px;
    border-color: #ff92a6;
    margin: 5px;
}

button:focus, button:active, button:hover {
    background-color: #ff92a6;
    outline-style: none;
}
EEOF

# Create scratchpad toggle script
mkdir -p ~/.config/hypr/scripts
cat << 'EEOF' > ~/.config/hypr/scripts/scratchpad.sh
#!/usr/bin/env bash

SCRATCHPAD_NAME="scratchpad"
TERMINAL="kitty --class $SCRATCHPAD_NAME"

if ! hyprctl clients | grep -q "class: $SCRATCHPAD_NAME"; then
    $TERMINAL
else
    hyprctl dispatch togglespecialworkspace $SCRATCHPAD_NAME
fi
EEOF
chmod +x ~/.config/hypr/scripts/scratchpad.sh

# Add to existing hyprland.conf
cat << 'EEOF' >> ~/.config/hypr/hyprland.conf

# Advanced window swallowing
misc {
    enable_swallow = true
    swallow_regex = ^(kitty)$
    swallow_exception_regex = ^(wev)$
}

# Scratchpad
bind = $mainMod SHIFT, S, exec, ~/.config/hypr/scripts/scratchpad.sh
bind = $mainMod, S, togglespecialworkspace, scratchpad

# Window resize mode
bind = $mainMod, R, submap, resize
submap = resize
binde = , right, resizeactive, 10 0
binde = , left, resizeactive, -10 0
binde = , up, resizeactive, 0 -10
binde = , down, resizeactive, 0 10
bind = , escape, submap, reset
submap = reset

# Gestures
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
}

# Dynamic workspaces
workspace = 1, name:DEV, persistent:true
workspace = 2, name:WWW, persistent:true
workspace = 3, name:CHAT, persistent:true
workspace = 4, name:MUSIC, persistent:true
workspace = 5, name:GAMES, persistent:true

# Advanced window rules
windowrulev2 = float,class:^(pavucontrol)$
windowrulev2 = float,title:^(Picture-in-Picture)$
windowrulev2 = float,class:^(file_progress)$
windowrulev2 = float,class:^(confirm)$
windowrulev2 = float,class:^(dialog)$
windowrulev2 = float,class:^(download)$
windowrulev2 = float,class:^(notification)$
windowrulev2 = float,class:^(error)$
windowrulev2 = float,class:^(confirmreset)$
windowrulev2 = animation popin,class:^(kitty)$,title:^(update-sys)$
windowrulev2 = workspace 2, class:^(firefox)$
windowrulev2 = workspace 3, class:^(discord)$
windowrulev2 = workspace 4, class:^(spotify)$

# Screen recording
bind = $mainMod SHIFT, R, exec, wf-recorder -g "$(slurp)"
bind = $mainMod ALT, R, exec, killall -s SIGINT wf-recorder

# Clipboard management
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
bind = $mainMod, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy

# RGB keyboard effects (if supported)
exec-once = openrgb --device 0 --mode rainbow
EEOF

# Create fancy lock screen config
cat << 'EEOF' > ~/.config/hypr/hyprlock.conf
background {
    monitor =
    path = ~/wallpaper.jpg
    blur_size = 5
    blur_passes = 3
    noise = 0.0117
    contrast = 1.3000
    brightness = 0.8000
    vibrancy = 0.2100
    vibrancy_darkness = 0.0
}

input-field {
    monitor =
    size = 250, 50
    outline_thickness = 2
    dots_size = 0.2
    dots_spacing = 0.2
    dots_center = true
    outer_color = rgb(ff92a6)
    inner_color = rgb(200, 200, 200)
    font_color = rgb(10, 10, 10)
    fade_on_empty = true
    placeholder_text = <i>Password...</i>
    hide_input = false
    position = 0, -20
    halign = center
    valign = center
}

label {
    monitor =
    text = Hi there, $USER!
    color = rgba(200, 200, 200, 1.0)
    font_size = 25
    font_family = JetBrainsMono Nerd Font
    position = 0, 80
    halign = center
    valign = center
}
EEOF

# Create idle configuration
cat << 'EEOF' > ~/.config/hypr/hypridle.conf
listener {
    timeout = 300
    on-timeout = hyprlock
}

listener {
    timeout = 380
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 1800
    on-timeout = systemctl suspend
}
EEOF

# Make scripts executable
chmod +x ~/.config/hypr/scripts/*

echo -e "\n\033[0;32mExtras installation completed! 🎉\033[0m"
echo -e "\033[0;34mRestart Hyprland to apply all new features.\033[0m"
echo -e "\033[0;35mNew keyboard shortcuts:\033[0m"
echo "• Super + Shift + S: Toggle scratchpad"
echo "• Super + R: Enter resize mode"
echo "• Super + Shift + R: Start screen recording"
echo "• Super + Alt + R: Stop screen recording"
echo "• Super + V: Clipboard history"
