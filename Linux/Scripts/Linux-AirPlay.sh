#!/usr/bin/env bash
# ===============================================================
# AirPlay Dual-Way Setup for Arch/Manjaro KDE (Wayland Ready)
# All-in-One — Auto-detect user/UID, force bypass, verified tray
# Auto-opens logs on service errors
# Maintainer: duckyonquack-999 / QuackLabs Solutions
# Patched: Nov 2025 – User service, PipeWire RAOP, FDH2/UxPlay, error handling
# + Bypass: Update errors skipped with warning
# + Retry: 3-attempt loop for system updates with 10s delays
# + UI: Advanced Yad dialogs (fork of Zenity: forms, menus, icons)
# + Notify: Desktop notifications via notify-send for progress/alerts
# + Progress: Yad bars for long-running tasks (pulsate/percentage)
# + Uninstall: Complete removal fn + reinstall prompt if exists
# ===============================================================

set -e

# Detect current user and UID
USER_NAME=$(whoami)
USER_UID=$(id -u)

SERVICE="uxplay-wayland.service"

# Defaults
HOSTNAME="Linux-AirPlay"
RESOLUTION="1920x1080"
REFRESH_RATE="60"

notify_progress() {
    notify-send --urgency=low --hint int:transient:1 "AirPlay Setup" "$1" || echo "$1"
}

notify_success() {
    notify-send --urgency=low --hint int:transient:1 "AirPlay Setup" "✅ $1" || echo "✅ $1"
}

notify_error() {
    notify-send --urgency=normal --hint int:transient:1 "AirPlay Setup" "⚠️ $1" || echo "⚠️ $1"
}

# Advanced config form (Yad)
config_form() {
    if command -v yad &>/dev/null; then
        local config=$(yad --form --title="AirPlay Setup Config" \
            --text="Configure Receiver Settings" \
            --field="Hostname:TEXT" "$HOSTNAME" \
            --field="Resolution:LBL" "$RESOLUTION" \
            --field="Refresh Rate (Hz):NUM" "$REFRESH_RATE" \
            --field=":BTN" "gtk-cancel|Cancel|gtk-ok|OK" \
            --width=400 --height=200 --button=gtk-cancel:1 --button=gtk-ok:0)
        if [ $? -eq 1 ]; then
            notify_error "Setup cancelled by user."
            exit 1
        fi
        IFS='|' read -r HOSTNAME RESOLUTION RESOLUTION REFRESH_RATE <<< "$config"
        echo "Config: Hostname=$HOSTNAME, Res=$RESOLUTION, Rate=$REFRESH_RATE"
    else
        echo "Yad unavailable; using defaults: $HOSTNAME @ $RESOLUTION $REFRESH_RATE Hz"
    fi
}

# Progress bar wrapper (Yad)
progress_bar() {
    local title="$1"
    local start_pct="$2"
    local end_pct="$3"
    local cmd="$4"
    local pid

    if command -v yad &>/dev/null; then
        {
            echo "$start_pct"
            if [ -n "$cmd" ]; then
                eval "$cmd" 2>/dev/null
                echo "$end_pct"
            else
                # Pulsate for indeterminate
                while true; do
                    echo "# Pulsing..."
                    sleep 1
                done
            fi
        } | yad --progress --title="$title" --text="$title" --percentage="$start_pct" --auto-close --undecorated --width=400 --height=100 &
        pid=$!
        trap "kill $pid 2>/dev/null || true" EXIT
        wait $pid
        trap - EXIT
    else
        echo ">>> $title (progress unavailable)"
        [ -n "$cmd" ] && eval "$cmd"
    fi
}

# Uninstall UxPlay completely
uninstall_uxplay() {
    echo ">>> Uninstalling UxPlay..."
    notify_progress "Uninstalling UxPlay receiver..."
    # Stop and disable service
    systemctl --user stop $SERVICE || true
    systemctl --user disable $SERVICE || true
    rm -f "$HOME/.config/systemd/user/$SERVICE" || true
    # Remove binary and docs
    sudo rm -f /usr/local/bin/uxplay || true
    sudo rm -f /usr/local/share/man/man1/uxplay.1 || true
    sudo rm -rf /usr/local/share/doc/uxplay || true
    # Clean build dir
    rm -rf /tmp/uxplay || true
    notify_success "UxPlay uninstalled completely."
}

# Initial config
config_form

echo ">>> 🔧 Preparing system..."
sudo rm -f /var/lib/pacman/db.lck || true
notify_progress "Preparing system..."

echo ">>> ⚙️ Refreshing mirrors and keyrings..."
sudo pacman -Sy --noconfirm reflector archlinux-keyring || true
sudo pacman-key --init || true
sudo pacman-key --populate archlinux manjaro || true
sudo pacman-key --refresh-keys || true
notify_progress "Mirrors refreshed."

echo ">>> 🧱 System update (retry logic)..."
max_retries=3
update_success=false
for ((i=1; i<=max_retries; i++)); do
    echo "Attempt $i/$max_retries"
    if sudo pacman -Syu --needed; then
        notify_success "System update completed."
        update_success=true
        break
    else
        if [ $i -eq $max_retries ]; then
            notify_error "Update failed after $max_retries attempts – using cached pkgs."
        else
            echo "⚠️ Update attempt $i/$max_retries failed. Retrying in 10s..."
            sleep 10
        fi
    fi
done
[ "$update_success" = false ] && echo "Note: Manual 'sudo pacman -Syu' recommended later."

echo ">>> 🚀 Installing dependencies..."
progress_bar "Installing Dependencies..." 0 100 \
  "sudo pacman -S --needed --disable-download-timeout \
  base-devel git cmake avahi libplist openssl \
  gstreamer gst-plugins-{base,good,bad,ugly} gst-libav \
  sdl2 ffmpeg \
  pulseaudio pulseaudio-zeroconf pipewire pipewire-pulse \
  python python-pip \
  xdg-utils desktop-file-utils yad \
  vlc libnotify konsole" || { notify_error "Dependencies install failed"; exit 1; }
notify_progress "Dependencies installed."

# ===============================================================
# 🛰️ Install UxPlay Receiver (with reinstall option)
# ===============================================================
if command -v uxplay &>/dev/null; then
    echo ">>> UxPlay detected – Check for reinstall..."
    if command -v yad &>/dev/null; then
        if yad --question --title="UxPlay Already Installed" --text="UxPlay is already installed. Reinstall (uninstall first)?" --width=300 --height=100 --image=gtk-dialog-question; then
            uninstall_uxplay
            # Proceed to fresh install
        else
            notify_success "UxPlay receiver ready (skipping install)."
            echo ">>> Skipping UxPlay install."
            exit 0  # Or continue, but since main goal is UxPlay, exit clean
        fi
    else
        echo "Yad unavailable; skipping reinstall prompt. UxPlay ready."
        exit 0
    fi
fi

echo ">>> Installing UxPlay..."
notify_progress "Building UxPlay receiver..."
rm -rf /tmp/uxplay || true
progress_bar "Cloning UxPlay Repo..." 0 20 \
  "git clone https://github.com/FDH2/UxPlay.git /tmp/uxplay" || { notify_error "Git clone failed – Check network/repo"; exit 1; }
cd /tmp/uxplay && mkdir -p build && cd build
progress_bar "Configuring Build..." 20 40 \
  "cmake .. -DNO_X11_DEPS=ON" || { notify_error "CMake failed – Missing deps?"; exit 1; }
progress_bar "Compiling..." 40 90 \
  "make -j$(nproc)" || { notify_error "Make failed – Build error"; exit 1; }
progress_bar "Installing..." 90 100 \
  "sudo make install" || { notify_error "Install failed – Permissions?"; exit 1; }
cd ~
notify_success "UxPlay receiver installed."

# ===============================================================
# 🔊 Setup PulseAudio/PipeWire RAOP2 (Linux → Apple)
# ===============================================================
echo ">>> Configuring RAOP2..."
notify_progress "Configuring audio (RAOP2)..."
# Detect audio server
if pactl info | grep -q "Server Name: PulseAudio"; then
    # Pure PulseAudio
    if ! pactl list short modules | grep -q raop-discover; then
        pactl load-module module-raop-discover || { notify_error "RAOP load failed"; exit 1; }
    fi
    PA_CONF="$HOME/.config/pulse/default.pa"
    mkdir -p "$(dirname "$PA_CONF")"
    if ! grep -q "raop-discover" "$PA_CONF" 2>/dev/null; then
        echo "load-module module-raop-discover" >> "$PA_CONF"
    fi
    # Reload if needed
    pulseaudio -k && pulseaudio --start || true
    notify_success "PulseAudio RAOP configured."
else
    # PipeWire (default 2025)
    echo ">>> PipeWire detected – Loading RAOP discover..."
    PW_CONF="$HOME/.config/pipewire/pipewire.conf.d/raop.conf"
    mkdir -p "$(dirname "$PW_CONF")"
    cat > "$PW_CONF" <<EOF
context.modules = [
    { name = libpipewire-module-raop-discover }
]
EOF
    # Restart PipeWire session
    progress_bar "Restarting PipeWire..." 0 100 \
      "systemctl --user restart pipewire pipewire-pulse" || { notify_error "PipeWire restart failed – Fallback: Install shairport-sync for RAOP sinks"; exit 1; }
    notify_success "PipeWire RAOP configured."
fi

# ===============================================================
# 🧠 Create systemd user service for UxPlay (Wayland)
# ===============================================================
echo ">>> Setting up UxPlay service..."
notify_progress "Creating Wayland service..."
SERVICE_FILE="$HOME/.config/systemd/user/$SERVICE"
mkdir -p "$(dirname "$SERVICE_FILE")"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=UxPlay AirPlay Receiver (Wayland)
After=network.target graphical-session.target
Wants=avahi-daemon.service

[Service]
Type=simple
ExecStart=/usr/local/bin/uxplay -n "$HOSTNAME" -r $REFRESH_RATE -d $RESOLUTION -vs waylandsink -as pulsesink
Restart=on-failure
Environment=WAYLAND_DISPLAY=wayland-0

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable $SERVICE || { notify_error "User service enable failed"; exit 1; }
notify_success "UxPlay service enabled."

# ===============================================================
# 🖥️ Create .desktop launcher entries
# ===============================================================
echo ">>> Creating launchers..."
notify_progress "Setting up desktop launchers..."
mkdir -p ~/.local/share/applications

# Receiver Launcher
cat > ~/.local/share/applications/airplay-receiver.desktop <<EOF
[Desktop Entry]
Name=AirPlay Receiver (Wayland)
Comment=Mirror iPhone/iPad screen to Linux
Exec=uxplay -n "$HOSTNAME" -r $REFRESH_RATE -d $RESOLUTION -vs waylandsink -as pulsesink
Icon=multimedia-player
Terminal=false
Type=Application
Categories=AudioVideo;Network;RemoteAccess;
StartupNotify=true
EOF

# ===============================================================
# 🪶 Tray Control Script with Auto-Log on Error (Yad Advanced UI + Notify)
# ===============================================================
TRAY_SCRIPT="$HOME/.local/bin/airplay-tray"
mkdir -p "$(dirname "$TRAY_SCRIPT")"
cat > "$TRAY_SCRIPT" <<'EOF'
#!/usr/bin/env bash
SERVICE="uxplay-wayland.service"

notify_tray() {
    notify-send --urgency=low --hint int:transient:1 "AirPlay Control" "$1" || echo "$1"
}

# Yad advanced menu with icons
ACTION=$(yad --menu --title="AirPlay Control" --text="Select Action" \
  --width=300 --height=200 \
  --button=gtk-cancel:1 \
  --entry-order=1 \
  "Start Receiver" "media-playback-start" \
  "Stop Receiver" "media-playback-stop" \
  "Status" "dialog-information")

case "$ACTION" in
  "Start Receiver")
    systemctl --user start $SERVICE
    for i in {1..5}; do
        sleep 2
        STATUS=$(systemctl --user is-active $SERVICE)
        [ "$STATUS" = "active" ] && break
    done
    if [ "$STATUS" = "active" ]; then
        yad --info --title="AirPlay Receiver" --text="✅ Receiver started successfully." --width=300 --height=100 --image=gtk-apply
        notify_tray "Receiver started successfully."
    else
        yad --error --title="AirPlay Receiver" --text="⚠️ Failed to start receiver. Logs will open." --width=300 --height=100 --image=gtk-dialog-error
        notify_tray "Failed to start receiver."
        konsole --noclose -e journalctl --user -u $SERVICE --no-pager &
    fi
    ;;
  "Stop Receiver")
    systemctl --user stop $SERVICE
    for i in {1..5}; do
        sleep 2
        STATUS=$(systemctl --user is-active $SERVICE || echo "inactive")
        [ "$STATUS" = "inactive" ] && break
    done
    if [ "$STATUS" = "inactive" ]; then
        yad --info --title="AirPlay Receiver" --text="✅ Receiver stopped successfully." --width=300 --height=100 --image=gtk-apply
        notify_tray "Receiver stopped successfully."
    else
        yad --error --title="AirPlay Receiver" --text="⚠️ Failed to stop receiver. Logs will open." --width=300 --height=100 --image=gtk-dialog-error
        notify_tray "Failed to stop receiver."
        konsole --noclose -e journalctl --user -u $SERVICE --no-pager &
    fi
    ;;
  "Status")
    STATUS=$(systemctl --user is-active $SERVICE || echo "inactive")
    yad --info --title="AirPlay Receiver Status" --text="Receiver is currently: $STATUS" --width=300 --height=100 --image=gtk-dialog-info
    notify_tray "Receiver status: $STATUS"
    ;;
  "")
    yad --info --title="AirPlay Receiver" --text="No action selected." --width=300 --height=100 --image=gtk-dialog-info
    ;;
esac
EOF

chmod +x "$TRAY_SCRIPT"

# Tray .desktop entry
cat > ~/.local/share/applications/airplay-tray.desktop <<EOF
[Desktop Entry]
Name=AirPlay Control
Comment=Manage AirPlay Receiver Service
Exec=$TRAY_SCRIPT
Icon=network-wireless
Terminal=false
Type=Application
Categories=AudioVideo;System;Utility;
StartupNotify=true
EOF

update-desktop-database ~/.local/share/applications || true
notify_success "Launchers and tray control ready."

# ===============================================================
# ✅ Verify UxPlay service is running
# ===============================================================
echo ">>> Verifying UxPlay service..."
notify_progress "Verifying service..."
systemctl --user start $SERVICE || true  # Gentle start if not running
for i in {1..5}; do
    STATUS=$(systemctl --user is-active $SERVICE || echo "inactive")
    if [ "$STATUS" = "active" ]; then
        echo "✅ UxPlay receiver is running."
        notify_success "UxPlay service active."
        break
    else
        echo "⏳ Waiting for service to start... ($i/5)"
        sleep 3
    fi
done

if [ "$STATUS" != "active" ]; then
    echo "⚠️ UxPlay did not start properly. Logs will open in Konsole."
    notify_error "UxPlay service failed to start."
    konsole --noclose -e journalctl --user -u $SERVICE --no-pager &
fi

# ===============================================================
# 🎉 Done
# ===============================================================
notify_success "AirPlay Dual-Way Setup Complete!"
echo "=============================================================="
echo "✅ AirPlay Dual-Way Setup Complete! (Uninstall/Reinstall Patch)"
echo "Receiver: iPhone/iPad → Linux via UxPlay (Wayland)"
echo "Sender: Linux → AppleTV/HomePod via RAOP2 (PipeWire/Pulse)"
echo "VLC Renderer: Playback → Renderer → AppleTV"
echo "Tray Control: AirPlay Control (Yad forms/menus + notify-send)"
echo "Note: Updates retried 3x; manual 'sudo pacman -Syu' if needed."
echo "=============================================================="
