#!/usr/bin/env bash
set -euo pipefail

APPDIR="$HOME/Applications"
APPIMAGE="$APPDIR/cursor.appimage"
TMPFILE="$(mktemp)"
UNIT_DIR="$HOME/.config/systemd/user"
LOGFILE="$APPDIR/cursor-updater.log"

REPO_URL="https://api.github.com/repos/getcursor/cursor/releases/latest"

fix_permissions() {
    echo "[INFO] Fixing read-only filesystem and permissions..."
    sudo mount -o remount,rw /
    chmod -R u+rwX,g+rwX "$HOME/.config/Cursor" 2>/dev/null || true
    chmod -R u+rwX,g+rwX "$HOME/.vscode*" 2>/dev/null || true
    chmod -R u+rwX,g+rwX "$HOME/.cursor" 2>/dev/null || true
    chmod +x "$APPIMAGE" 2>/dev/null || true
}

fetch_latest_cursor() {
    echo "[INFO] Fetching latest Cursor AppImage release..."
    curl -sL "$REPO_URL" | grep "browser_download_url.*AppImage" | head -n 1 | cut -d '"' -f 4 >"$TMPFILE"
    local url
    url=$(cat "$TMPFILE")
    if [[ -z "$url" ]]; then
        echo "[ERROR] Failed to fetch latest Cursor release URL."
        exit 1
    fi
    echo "[INFO] Downloading Cursor from $url"
    curl -L -o "$APPIMAGE.new" "$url"
    chmod +x "$APPIMAGE.new"
    mv -f "$APPIMAGE.new" "$APPIMAGE"
}

install_systemd_unit() {
    echo "[INFO] Installing systemd user service + timer..."
    mkdir -p "$UNIT_DIR"

    cat >"$UNIT_DIR/cursor-updater.service" <<EOF
[Unit]
Description=Auto-update Cursor IDE and fix permissions
After=network-online.target

[Service]
Type=oneshot
ExecStart=$APPDIR/cursor-manager.sh --update
EOF

    cat >"$UNIT_DIR/cursor-updater.timer" <<EOF
[Unit]
Description=Run Cursor IDE updater every 12 hours

[Timer]
OnBootSec=1min
OnUnitActiveSec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now cursor-updater.timer
    echo "[INFO] Systemd timer enabled for auto-updates."
}

handle_signature_errors() {
    echo "[INFO] Handling signature trust issues..."
    sudo rm -rf /etc/pacman.d/gnupg
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
    sudo pacman-key --lsign-key "linux-maintainers@warp.dev" || true
    sudo pacman -Sy --disable-download-timeout --needed --noconfirm
    echo "[INFO] Signature system reset complete."
}

case "${1:-}" in
--install)
    echo "[INSTALL] Initializing Cursor Manager..."
    mkdir -p "$APPDIR"
    fix_permissions
    fetch_latest_cursor
    install_systemd_unit
    echo "[DONE] Cursor Manager installed and scheduled for updates."
    ;;
--update)
    echo "[UPDATE] Checking for new version..."
    fix_permissions
    fetch_latest_cursor
    echo "$(date) - Cursor updated successfully." >>"$LOGFILE"
    ;;
--repair)
    echo "[REPAIR] Resetting signature trust and remounting..."
    handle_signature_errors
    fix_permissions
    ;;
*)
    echo "Usage: $0 --install | --update | --repair"
    ;;
esac
