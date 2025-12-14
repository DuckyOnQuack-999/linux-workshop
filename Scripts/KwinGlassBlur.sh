#!/usr/bin/env bash
# ===============================================================
# KwinGlassBlur Installer + Dev Watch (with Shader Hot-Reload)
# ===============================================================
# Author: DuckyOnQuack-999
# Description:
#   - Full clean reinstall of forceblur source as 'kwin-glassblur'
#   - Installs companion KWin script KwinGlassBlur
#   - Configurable blur radius, opacity, etc.
#   - Dev modes: --dev-watch and --shader-watch
# ===============================================================

set -euo pipefail
IFS=$'\n\t'

# ---------------------------
# Config defaults
# ---------------------------
REPO="https://github.com/taj-ny/kwin-effects-forceblur.git"
CUSTOM_NAME="kwin-glassblur"
PROJECT_DIR="$HOME/Projects/kwin-effects-${CUSTOM_NAME}"
BUILD_DIR="$PROJECT_DIR/build"
SCRIPT_NAME="KwinGlassBlur"
SCRIPT_DIR="$HOME/.local/share/kwin/scripts/$SCRIPT_NAME"

# Visual tuning
RADIUS=25
OPACITY=0.88
BRIGHTNESS=1.0
CONTRAST=1.08
NOISE=0.02
SELECTIVE_CLASSES=""

# watch mode flags
DEV_WATCH=false
SHADER_WATCH=false
JOBS="$(nproc)"

# ---------------------------
# CLI parsing
# ---------------------------
usage() {
    cat <<EOF
Usage: $0 [options]
  --dev-watch           Watch entire source for rebuild
  --shader-watch        Watch shader files only (fast rebuild)
  --radius N            Blur radius (default $RADIUS)
  --opacity V           Opacity (default $OPACITY)
  --classes "a,b,c"     Only apply blur to specific window classes
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --dev-watch)
        DEV_WATCH=true
        shift
        ;;
    --shader-watch)
        SHADER_WATCH=true
        shift
        ;;
    --radius)
        RADIUS="$2"
        shift 2
        ;;
    --opacity)
        OPACITY="$2"
        shift 2
        ;;
    --classes)
        SELECTIVE_CLASSES="$2"
        shift 2
        ;;
    --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown arg: $1"
        usage
        exit 1
        ;;
    esac
done

# ---------------------------
# Utilities
# ---------------------------
info() { echo -e "\e[1;32m[INFO] $*\e[0m"; }
warn() { echo -e "\e[1;33m[WARN] $*\e[0m"; }
die() {
    echo -e "\e[1;31m[ERROR] $*\e[0m"
    exit 1
}
command_exists() { command -v "$1" >/dev/null 2>&1; }

for t in git cmake make; do
    command_exists $t || die "Missing $t"
done

if [ "$DEV_WATCH" = true ] || [ "$SHADER_WATCH" = true ]; then
    command_exists inotifywait || die "Install inotify-tools first."
fi

# ---------------------------
# Paths
# ---------------------------
TMP_BACKUP_DIR="/tmp/kwin_glassblur_backup_$(date +%s)"
mkdir -p "$TMP_BACKUP_DIR"
KWINRC="$HOME/.config/kwinrc"
EFFECT_DIRS=(/usr/lib/qt6/plugins/kwin/effects /usr/lib/qt/plugins/kwin/effects)

# ---------------------------
# Backup + Cleanup
# ---------------------------
backup_and_remove_old() {
    info "Backing up and cleaning old installs..."
    for dir in "${EFFECT_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        for f in "$dir"/*glassblur*.so "$dir"/*forceblur*.so; do
            [ -f "$f" ] || continue
            sudo cp "$f" "$TMP_BACKUP_DIR/" || true
            sudo rm -f "$f"
        done
    done
    [ -d "$SCRIPT_DIR" ] && mv "$SCRIPT_DIR" "$TMP_BACKUP_DIR/" || true
    kpackagetool6 --type KWin/Script --remove "$SCRIPT_NAME" &>/dev/null || true
}

# ---------------------------
# Clone/Update Source
# ---------------------------
clone_or_update_source() {
    if [ -d "$PROJECT_DIR/.git" ]; then
        info "Updating source..."
        git -C "$PROJECT_DIR" pull --rebase || true
    else
        info "Cloning source..."
        git clone "$REPO" "$PROJECT_DIR"
    fi
}

# ---------------------------
# Build & Install Plugin
# ---------------------------
build_and_install_plugin() {
    info "Building plugin..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    pushd "$BUILD_DIR" >/dev/null
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build . -- -j"$JOBS"
    sudo cmake --install .
    popd >/dev/null
}

# ---------------------------
# Fast Shader Rebuild
# ---------------------------
fast_shader_update() {
    pushd "$BUILD_DIR" >/dev/null
    cmake --build . -- -j"$JOBS"
    sudo cmake --install .
    popd >/dev/null
    qdbus org.kde.KWin /KWin reconfigure &>/dev/null || true
}

# ---------------------------
# Install Script
# ---------------------------
install_kwin_script() {
    info "Installing KWin script..."
    rm -rf "$SCRIPT_DIR"
    mkdir -p "$SCRIPT_DIR/contents/code"

    cat >"$SCRIPT_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=$SCRIPT_NAME
Comment=Glass-like transparency & blur control
Type=Service
X-KDE-ServiceTypes=KWin/Script
X-KDE-PluginInfo-Name=$SCRIPT_NAME
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-Author=DuckyOnQuack-999
X-KDE-PluginInfo-EnabledByDefault=true
EOF

    cat >"$SCRIPT_DIR/contents/code/main.js" <<EOF
var blurEnabled = true;
function applyGlass(client) {
  if (!client) return;
  client.blurBehind = blurEnabled;
  if (client.opacity !== undefined)
    client.opacity = $OPACITY;
}
workspace.clientAdded.connect(applyGlass);
workspace.clientActivated.connect(applyGlass);
registerShortcut("ToggleKwinGlassBlur","Toggle Glass Blur","Meta+Shift+B",function(){
  blurEnabled = !blurEnabled;
  workspace.clientList().forEach(applyGlass);
});
EOF

    kpackagetool6 --type KWin/Script --install "$SCRIPT_DIR"
}

# ---------------------------
# Apply Config
# ---------------------------
apply_kwin_config() {
    kwriteconfig6 --file "$KWINRC" --group Plugins --key ${SCRIPT_NAME}Enabled true || true
    kwriteconfig6 --file "$KWINRC" --group $SCRIPT_NAME --key radius "$RADIUS" || true
    kwriteconfig6 --file "$KWINRC" --group $SCRIPT_NAME --key opacity "$OPACITY" || true
}

# ---------------------------
# Reload KWin
# ---------------------------
reload_kwin() {
    qdbus org.kde.KWin /KWin reconfigure &>/dev/null || kwin_x11 --replace &>/dev/null &
}

# ---------------------------
# Main pipeline
# ---------------------------
full_install() {
    backup_and_remove_old
    clone_or_update_source
    build_and_install_plugin
    install_kwin_script
    apply_kwin_config
    reload_kwin
    info "✅ Installed KwinGlassBlur successfully!"
}

full_install

# ---------------------------
# Watch Modes
# ---------------------------
if [ "$DEV_WATCH" = true ]; then
    info "Watching entire project..."
    inotifywait -m -r -e modify,create,delete,move "$PROJECT_DIR" --format '%w%f' | while read -r path; do
        info "[DEV] Change detected in: $path"
        build_and_install_plugin
        reload_kwin
    done
elif [ "$SHADER_WATCH" = true ]; then
    info "Watching shaders for hot reload..."
    inotifywait -m -r -e modify,create,delete,move "$PROJECT_DIR" --format '%w%f' | while read -r path; do
        if [[ "$path" =~ \.(frag|vert|glsl|qsb)$ ]]; then
            info "[SHADER] Change detected in: $path"
            fast_shader_update
        fi
    done
fi
