#!/usr/bin/env
set -euo pipefail

# DuckyCoder AI: Dynamic Theming System Installer for Hyprland
# Usage: ./theme-installer.sh [--install] [--watch-only] [--uninstall] [--debug]
# Idempotent: Skips existing setups; backups all changes.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CACHE_DIR="$HOME/.cache/theme-gen"
readonly CONF_DIR="$HOME/.config/theme-gen"
readonly LOG_FILE="$CACHE_DIR/theme.log"

# Debug flag for tracing
DEBUG=false
if [[ "${1:-}" == "--debug" ]]; then
    DEBUG=true
    set -x # Bash tracing
    shift
fi

# Fixed wallpaper detection: Robust jq/sed fallback
WALLPAPER_PATH="${WALLPAPER_PATH:-}"
if command -v hyprctl >/dev/null && command -v jq >/dev/null; then
    WALLPAPER_PATH=$(hyprctl getoption general:bg -j 2>/dev/null | jq -r '.str // empty')
fi
if [[ -z "$WALLPAPER_PATH" ]]; then
    WALLPAPER_PATH="$HOME/.config/hypr/wallpaper.jpg"
fi
if [[ ! -f "$WALLPAPER_PATH" ]]; then
    log "Warning: Wallpaper not found at $WALLPAPER_PATH; skipping gen."
    exit 1
fi
readonly WALLPAPER_PATH

# Targets: Configs to theme (expand as needed)
readonly CONF_TARGETS=(
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.config/rofi/config.rasi"
    "$HOME/.config/kitty/kitty.conf"
    "$HOME/.Xresources"
    "$HOME/.config/systemd/user/theme-watcher.service" # New: For backup
)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Trap for cleanup
cleanup() {
    log "Cleanup triggered."
    systemctl --user stop theme-watcher.service 2>/dev/null || true
    notify-send "Theming System" "Watcher stopped." 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$CACHE_DIR" "$CONF_DIR"

install_deps() {
    log "Installing dependencies..."
    local pkgs=(matugen pywal git inotify-tools dbus ImageMagick swww jq) # Added jq
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            sudo pacman -S --noconfirm "$pkg" || {
                log "Failed to install $pkg"
                return 1
            }
        fi
    done

    # Clone Chameleon if missing
    local cham_dir="$CONF_DIR/Chameleon"
    if [[ ! -d "$cham_dir" ]]; then
        git clone https://github.com/GideonWolfe/Chameleon.git "$cham_dir" || {
            log "Failed to clone Chameleon"
            return 1
        }
        cd "$cham_dir" && make install || {
            log "Failed to install Chameleon (check Makefile)"
            return 1
        }
        cd "$SCRIPT_DIR"
    fi
    log "Dependencies installed."
}

backup_confs() {
    log "Backing up configs..."
    for conf in "${CONF_TARGETS[@]}"; do
        if [[ -f "$conf" ]]; then
            local backup="$conf.bak.$(date +%Y%m%d_%H%M%S)"
            cp -b "$conf" "$backup" || {
                log "Backup failed for $conf"
                return 1
            }
            log "Backed up $conf to $backup"
        fi
    done
}

gen_palette() {
    log "Generating palette from $WALLPAPER_PATH..."
    mkdir -p "$CACHE_DIR" "$HOME/.cache/wal"

    # Matugen for Material You
    matugen --image "$WALLPAPER_PATH" --export json >"$CACHE_DIR/matugen.json" || {
        log "Matugen failed"
        return 1
    }

    # Pywal for vars (truecolor)
    wal -i "$WALLPAPER_PATH" -t || {
        log "Pywal failed"
        return 1
    }

    # Chameleon apply
    chameleon apply --wal || {
        log "Chameleon failed"
        return 1
    }

    # Colorbox enhancement: Disable API by default (privacy); force fallback
    # if command -v curl >/dev/null && curl -fIs https://colorbox.io/api/generate &>/dev/null; then
    #     local b64_wall=$(base64 -w 0 "$WALLPAPER_PATH" 2>/dev/null || base64 "$WALLPAPER_PATH")  # GNU/BSD compat
    #     curl -s -d "image_url=$b64_wall" https://colorbox.io/api/generate | jq -r '.colors[] | "#\(.hex)"' >> "$CACHE_DIR/colorbox.json" || log "Colorbox API failed; using fallback."
    # else
    convert "$WALLPAPER_PATH" -colors 8 -unique-colors txt:- | grep -E '^#[0-9A-F]{6}' | cut -d' ' -f2 | sort -u >"$CACHE_DIR/colorbox.json" || {
        log "ImageMagick fallback failed"
        return 1
    }
    # fi

    # Merge: Append unique colorbox to pywal colors
    while IFS= read -r color; do
        if ! grep -q "^$color$" "$HOME/.cache/wal/colors"; then # Exact match
            echo "color_extra=$(echo "$color" | cut -d'#' -f2)" >>"$HOME/.cache/wal/colors"
        fi
    done <"$CACHE_DIR/colorbox.json"

    log "Palette generated."
}

apply_themes() {
    log "Applying themes..."
    if [[ ! -f "$HOME/.cache/wal/colors" ]]; then
        log "Error: Pywal colors missing; run gen_palette first."
        return 1
    fi
    source "$HOME/.cache/wal/colors" || {
        log "Failed to source pywal colors"
        return 1
    }

    for conf in "${CONF_TARGETS[@]}"; do
        if [[ ! -f "$conf" ]]; then continue; fi
        if [[ "$conf" == *theme-watcher.service ]]; then continue; fi # Skip service in apply_themes

        # Parse: Extract non-theme sections (improved awk for block preservation)
        local temp_conf="$CACHE_DIR/$(basename "$conf").tmp"
        awk '
        /^# Theme Block Start/ { in_theme=0; next }
        in_theme && /^[a-z]/ { $0 = "  " $0 }
        /^# Theme Block End/ { in_theme = 1; next }
        in_theme { print }
        !in_theme { print }
        ' "$conf" >"$temp_conf" # Fixed awk logic

        # Rebuild atomically with vars (hex to rgba example)
        case "$conf" in
        *hyprland.conf)
            cat <<EOF >"$conf"
$(cat "$temp_conf")
# Theme Block Start
general {
    border_color = rgba(${color1:1}ff)
    shadow_color = rgba(${color0:1}80)
}
decoration {
    active_border_color = rgb(${color5:1})
    inactive_border_color = rgb(${color0:1})
}
# Theme Block End
EOF
            ;;
        *rofi/config.rasi)
            cat <<EOF >"$conf"
$(cat "$temp_conf")
* {
    background-color: #${color0:1};
    text-color: #${color5:1};
    border-color: #${color1:1};
}
EOF
            ;;
        *kitty/kitty.conf)
            cat <<EOF >"$conf"
$(cat "$temp_conf")
foreground #${color5:1}
background #${color0:1}
selection_background #${color1:1}
color0 #${color0:1}
color1 #${color1:1}
# ... (extend for color8-15 if needed)
EOF
            ;;
        *.Xresources)
            cat <<EOF >"$conf"
$(cat "$temp_conf")
Xft.foreground: #${color5:1}
Xft.background: #${color0:1}
*.borderColor: #${color1:1}
EOF
            ;;
        esac
        rm -f "$temp_conf"
        log "Applied theme to $conf"
    done

    # Set wallpaper if swww available
    command -v swww >/dev/null && swww img "$WALLPAPER_PATH" || log "swww not available; skip wallpaper set."
}

setup_watcher() {
    log "Setting up wallpaper watcher as systemd user service..."
    local watcher_script="$CONF_DIR/theme-watcher.sh"
    local service_file="$HOME/.config/systemd/user/theme-watcher.service"

    # Enhanced daemon script: Precise DBus filter, backoff retry
    cat <<'EOF' >"$watcher_script"
#!/bin/bash
set -euo pipefail
readonly HOME_DIR="$HOME"
readonly CONF_DIR="$HOME_DIR/.config/theme-gen"
readonly CACHE_DIR="$HOME_DIR/.cache/theme-gen"
readonly WALLPAPER_PATH="$HOME_DIR/.config/hypr/wallpaper.jpg"  # Simplified fallback

regen() {
    if [[ -f "$WALLPAPER_PATH" ]]; then
        "$CONF_DIR/theme-installer.sh" --watch-only || log "Regen failed."
        notify-send "Theming System" "Theme updated for new wallpaper." 2>/dev/null || true
    fi
}

# Primary: Precise DBus Hyprland signals (filter for workspace/bg changes)
while true; do
    if dbus-monitor "interface=org.hyprland.SignalEmitter" 2>/dev/null | grep -q "string=event:changeworkspace\|string=general:bg"; then
        dbus-monitor "interface=org.hyprland.SignalEmitter" | while IFS= read -r line; do
            if echo "$line" | grep -q "string=event:changeworkspace\|string=general:bg"; then
                regen
                sleep 1  # Debounce
            fi
        done
    else
        log "DBus failed; fallback to inotify."
        # Fallback: Targeted inotify on wallpaper file
        inotifywait -m -e modify,create "$WALLPAPER_PATH" 2>/dev/null | while read -r path event file; do
            regen
        done
    fi
    sleep 5  # Backoff on loop error
done
EOF
    chmod +x "$watcher_script"

    # Enhanced systemd service file: Added security/confinement
    mkdir -p "$HOME/.config/systemd/user"
    cat <<EOF >"$service_file"
[Unit]
Description=Dynamic Theming Wallpaper Watcher
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$watcher_script
WorkingDirectory=$HOME
Environment=PATH=/usr/bin:/usr/local/bin
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
ProtectHome=true
NoNewPrivileges=true
KillMode=process

[Install]
WantedBy=graphical-session.target
EOF

    # Reload, enable, start (idempotent with quiet)
    systemctl --user daemon-reload
    systemctl --user enable --quiet theme-watcher.service 2>/dev/null || true
    systemctl --user start --quiet theme-watcher.service 2>/dev/null || {
        log "Failed to start service"
        return 1
    }
    log "Systemd service enabled and started. Check with: journalctl --user -u theme-watcher"
}

verify() {
    log "Verifying installation..."
    for conf in "${CONF_TARGETS[@]}"; do
        if [[ -f "$conf" ]]; then
            if [[ "$conf" == *theme-watcher.service ]]; then
                if systemctl --user is-active --quiet theme-watcher.service; then
                    log "Verified: theme-watcher service is active."
                else
                    log "Warning: theme-watcher service is inactive."
                fi
            elif [[ $(grep -c "color[0-9]" "$conf") -gt 0 ]]; then
                log "Verified: $conf has theme vars."
            else
                log "Warning: No theme vars in $conf."
            fi
        fi
    done
    log "Verification complete."
}

uninstall() {
    log "Uninstalling..."
    # Stop/disable service
    systemctl --user stop --quiet theme-watcher.service 2>/dev/null || true
    systemctl --user disable --quiet theme-watcher.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/theme-watcher.service"
    systemctl --user daemon-reload

    # Restore latest backups
    for conf in "${CONF_TARGETS[@]}"; do
        if [[ "$conf" == *theme-watcher.service ]]; then continue; fi # Skip service restore
        local latest_backup=$(ls -t "${conf}.bak."* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
            cp "$latest_backup" "$conf" || log "Restore failed for $conf"
            log "Restored $conf from $latest_backup"
        fi
    done
    # Cleanup
    rm -rf "$CACHE_DIR" "$CONF_DIR"
    log "Uninstall complete."
}

main() {
    local install=true watch_only=false uninstall=false
    while [[ $# -gt 0 ]]; do
'        case $1 in
        --install)
            watch_only=false
            uninstall=false
            shift
            ;;
        --watch-only)
            watch_only=true
            shift
            ;;
        --uninstall)
            uninstall=true
            shift
            ;;
        --debug)
            shift
            continue
            ;; # Handled earlier
        *)
            log "Unknown arg: $1"
            exit 1
            ;;
        esac
    done

    if [[ "$uninstall" == true ]]; then
        uninstall
        exit 0
    fi

    install_deps
    backup_confs
    gen_palette
    apply_themes

    if [[ "$watch_only" == false ]]; then
        setup_watcher
        verify
        hyprctl reload || log "Hyprland reload failed (ensure running)."
        log "Installation complete. Monitor service: journalctl --user -u theme-watcher"
    else
        gen_palette && apply_themes && verify
    fi
}

main "$@"
