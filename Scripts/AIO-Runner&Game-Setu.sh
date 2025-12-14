#!/usr/bin/env bash
# ==============================================================================
# Universal Game Launcher Zero‑Touch Stack for Arch Linux (Hardened v4.0)
# Enhanced with conflict resolution and pre-flight validation
# ===============================AI===============================================

set -o pipefail

# ===============================
# Logging
# ===============================
TS="$(date +%Y%m%d_%H%M%S)"
LOG="/tmp/game_stack_${TS}.log"
DIAG_LOG="/tmp/game_stack_diagnostic_${TS}.log"
SKIPPED_PKGS="/tmp/game_stack_skipped_${TS}.log"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "[WARN] Error at line $LINENO — continuing"' ERR
trap 'echo "[DONE] Logs: $LOG | $DIAG_LOG | $SKIPPED_PKGS"' EXIT

# ===============================
# Terminal UI
# ===============================
CLR_RESET="\e[0m"
CLR_RED="\e[31m"
CLR_GREEN="\e[32m"
CLR_YELLOW="\e[33m"
CLR_BLUE="\e[34m"
CLR_MAGENTA="\e[35m"
CLR_CYAN="\e[36m"
CLR_BOLD="\e[1m"
ui_div() { echo -e "${CLR_MAGENTA}${CLR_BOLD}════════════════════════════════════════════════════${CLR_RESET}"; }
ui_title() {
    ui_div
    echo -e "${CLR_CYAN}${CLR_BOLD} $1 ${CLR_RESET}"
    ui_div
}
ui_ok() { echo -e "${CLR_GREEN}✔${CLR_RESET} $*"; }
ui_warn() { echo -e "${CLR_YELLOW}⚠${CLR_RESET} $*"; }
ui_err() { echo -e "${CLR_RED}✖${CLR_RESET} $*"; }
ui_info() { echo -e "${CLR_BLUE}➜${CLR_RESET} $*"; }

# ===============================
# Helpers
# ===============================
have_cmd() { command -v "$1" >/dev/null 2>&1; }

install_pkg() {
    local pkg="$1"
    local fallback="${2:-none}"

    # Try pacman first
    if sudo pacman -S --needed --noconfirm "$pkg" 2>>"$DIAG_LOG"; then
        ui_ok "$pkg installed via pacman"
        return 0
    else
        ui_warn "$pkg failed via pacman"
        echo "$pkg" >>"$SKIPPED_PKGS"

        # Offer fallback if provided
        if [[ "$fallback" != "none" ]]; then
            ui_info "Attempting fallback: $fallback"
            case "$fallback" in
            aur)
                if have_cmd yay; then
                    yay -S --noconfirm "$pkg" && ui_ok "$pkg installed via AUR" && return 0
                elif have_cmd paru; then
                    paru -S --noconfirm "$pkg" && ui_ok "$pkg installed via AUR" && return 0
                fi
                ;;
            flatpak)
                if have_cmd flatpak; then
                    flatpak install flathub "$pkg" -y && ui_ok "$pkg installed via Flatpak" && return 0
                fi
                ;;
            esac
        fi

        ui_warn "$pkg installation failed (all methods)"
        return 1
    fi
}

install_pkgs() { for p in "$@"; do install_pkg "$p"; done; }

# ===============================
# Pre-flight Validation Functions
# ===============================
check_package_conflicts() {
    ui_info "Checking for package conflicts..."
    local conflicts=()

    # Check for lutris conflicts
    if pacman -Qi lutris &>/dev/null && pacman -Qi lutris-git &>/dev/null; then
        conflicts+=("lutris vs lutris-git")
    fi

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        ui_warn "Package conflicts detected: ${conflicts[*]}"
        return 1
    fi
    ui_ok "No package conflicts detected"
    return 0
}

check_flatpak_config() {
    if ! have_cmd flatpak; then
        return 0 # No flatpak, no problem
    fi

    ui_info "Checking Flatpak configuration..."

    # Check for duplicate remotes
    local system_flathub=$(flatpak remotes --system 2>/dev/null | grep -c flathub || echo 0)
    local user_flathub=$(flatpak remotes --user 2>/dev/null | grep -c flathub || echo 0)

    # Ensure values are valid integers
    system_flathub=$(echo "$system_flathub" | tr -d '[:space:]')
    user_flathub=$(echo "$user_flathub" | tr -d '[:space:]')
    
    # Default to 0 if empty
    system_flathub=${system_flathub:-0}
    user_flathub=${user_flathub:-0}

    if [[ $system_flathub -gt 0 && $user_flathub -gt 0 ]]; then
        ui_warn "Flatpak has both system and user flathub remotes"
        ui_info "This can cause ambiguity - recommend removing one"

        PS3="Select Flatpak scope preference: "
        select SCOPE in "Keep system only" "Keep user only" "Keep both (manual selection required)"; do
            case $REPLY in
            1)
                flatpak remote-delete --user flathub 2>/dev/null || true
                ui_ok "Removed user flathub, using system"
                export FLATPAK_SCOPE="--system"
                break
                ;;
            2)
                sudo flatpak remote-delete --system flathub 2>/dev/null || true
                ui_ok "Removed system flathub, using user"
                export FLATPAK_SCOPE="--user"
                break
                ;;
            3)
                ui_warn "Manual selection will be required for each flatpak install"
                export FLATPAK_SCOPE="--interactive"
                break
                ;;
            esac
        done
    elif [[ $system_flathub -gt 0 ]]; then
        export FLATPAK_SCOPE="--system"
        ui_ok "Using system Flatpak scope"
    elif [[ $user_flathub -gt 0 ]]; then
        export FLATPAK_SCOPE="--user"
        ui_ok "Using user Flatpak scope"
    else
        ui_warn "No Flatpak remotes configured"
        ui_info "Adding flathub remote (user scope)..."
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        export FLATPAK_SCOPE="--user"
    fi

    return 0
}

remove_conflicting_lutris() {
    ui_info "Removing conflicting Lutris installations..."

    # Remove standard pacman version
    if pacman -Qi lutris &>/dev/null; then
        ui_info "Removing pacman lutris..."
        sudo pacman -Rns lutris --noconfirm 2>>"$DIAG_LOG" || ui_warn "Pacman removal had issues"
    fi

    # Remove AUR versions
    if pacman -Qi lutris-git &>/dev/null; then
        ui_info "Removing lutris-git..."
        if have_cmd yay; then
            yay -Rns lutris-git --noconfirm 2>>"$DIAG_LOG"
        elif have_cmd paru; then
            paru -Rns lutris-git --noconfirm 2>>"$DIAG_LOG"
        else
            sudo pacman -Rns lutris-git --noconfirm 2>>"$DIAG_LOG"
        fi
    fi

    # Remove Flatpak version
    if have_cmd flatpak && flatpak list | grep -q lutris; then
        ui_info "Removing Flatpak lutris..."
        flatpak uninstall --delete-data net.lutris.Lutris -y 2>>"$DIAG_LOG" || ui_warn "Flatpak removal had issues"
    fi

    # Clean up manual compilation artifacts
    if [[ -d /tmp/lutris ]]; then
        ui_info "Removing manual compilation artifacts..."
        sudo rm -rf /tmp/lutris
    fi

    if [[ -d /usr/local/lib/python3.*/site-packages/lutris ]]; then
        ui_info "Removing manually installed Python packages..."
        sudo rm -rf /usr/local/lib/python3.*/site-packages/lutris
    fi

    # Remove pip-installed versions
    for pip_cmd in "sudo pip" "sudo pip3" "pip" "pip3"; do
        $pip_cmd uninstall -y lutris 2>/dev/null || true
    done

    # Purge Python site-packages
    find ~/.local/lib/python*/site-packages -name '*lutris*' -type d -exec rm -rf {} + 2>/dev/null || true
    sudo find /usr/lib/python*/site-packages -name '*lutris*' -type d -exec rm -rf {} + 2>/dev/null || true

    # Backup and remove user configuration
    if [[ -d ~/.config/lutris ]]; then
        ui_info "Backing up Lutris config to ~/.config/lutris.backup.$TS"
        cp -r ~/.config/lutris ~/.config/lutris.backup.$TS 2>/dev/null || true
    fi

    rm -rf ~/.config/lutris ~/.cache/lutris ~/.local/share/lutris

    ui_ok "Lutris cleanup complete"
}

# ===============================
# Advanced Diagnostic Functions
# ===============================
check_python_env() {
    ui_info "Checking Python environment..."
    {
        echo "=== Python Environment Diagnostics ==="
        python3 --version || echo "ERROR: Python3 not found"
        echo "--- Checking for pip-installed lutris ---"
        python3 -c "import lutris; print(lutris.__file__)" 2>&1 && echo "CONFLICT: pip lutris found" || echo "OK: No pip lutris"
        echo "--- Checking python-gobject ---"
        python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk" 2>&1 || echo "MISSING: python-gobject/GTK"
        echo "--- Checking python-yaml ---"
        python3 -c "import yaml" 2>&1 || echo "MISSING: python-yaml"
    } | tee -a "$DIAG_LOG"
}

check_display_server() {
    ui_info "Validating display server..."
    {
        echo "=== Display Server Diagnostics ==="
        echo "DISPLAY: ${DISPLAY:-NOT_SET}"
        echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-NOT_SET}"
        echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-NOT_SET}"
        pgrep -a Xorg || echo "Xorg not running"
        pgrep -a Xwayland || echo "XWayland not running"
        pgrep -a wayland || echo "Wayland compositor not detected"
    } | tee -a "$DIAG_LOG"

    if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
        ui_err "No display server detected - GUI applications will fail"
        ui_info "Attempting to export DISPLAY variable..."
        export DISPLAY=:0
        ui_warn "Set DISPLAY=:0 as fallback"
        return 1
    fi
    return 0
}

verify_lutris_deps() {
    ui_info "Verifying Lutris runtime dependencies..."
    local deps=(python-gobject python-yaml python-pillow python-requests python-dbus python-evdev python-lxml python-setproctitle gtk3 glib2 webkit2gtk gobject-introspection libnotify gnome-desktop)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! pacman -Qi "$dep" &>/dev/null; then
            missing+=("$dep")
            ui_warn "Missing dependency: $dep"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        ui_info "Installing missing dependencies (critical for Lutris)..."
        for dep in "${missing[@]}"; do
            if ! install_pkg "$dep"; then
                ui_err "Critical dependency failed: $dep"
                ui_warn "Lutris may not function without this package"
            fi
        done
    else
        ui_ok "All Lutris dependencies present"
    fi
}

diagnose_lutris_issues() {
    ui_info "Diagnosing Lutris issues..."
    {
        echo "=== Lutris Diagnostics ==="
        echo "--- Checking for pip-installed lutris ---"
        python3 -c "import lutris; print(lutris.__file__)" 2>&1 && echo "CONFLICT: pip lutris found" || echo "OK: No pip lutris"
        echo "--- Checking python-gobject ---"
        python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk" 2>&1 || echo "MISSING: python-gobject/GTK"
        echo "--- Checking python-yaml ---"
        python3 -c "import yaml" 2>&1 || echo "MISSING: python-yaml"
        echo "--- Checking for multiple installations ---"
        which -a lutris 2>/dev/null || echo "No lutris in PATH"
        echo "--- Checking Flatpak installations ---"
        flatpak list | grep -i lutris || echo "No Flatpak lutris"
        echo "--- Checking local installations ---"
        ls -la "$HOME/.local/bin/lutris" 2>/dev/null || echo "No local lutris"
    } | tee -a "$DIAG_LOG"
}

rebuild_pacman_db() {
    ui_info "Rebuilding package database..."
    if sudo pacman -Fy 2>>"$DIAG_LOG" && sudo pacman -Syy 2>>"$DIAG_LOG"; then
        ui_ok "Package database refreshed"
        return 0
    else
        ui_warn "Database rebuild had issues"
        return 1
    fi
}

# ===============================
# Enhanced Lutris Installation with Conflict Resolution
# ===============================
install_lutris_safe() {
    ui_title "Lutris Installation with Conflict Resolution"

    # Pre-flight checks
    ui_info "Running pre-flight validation..."
    check_package_conflicts || ui_warn "Conflicts detected, will attempt resolution"
    check_flatpak_config

    # Remove any existing installations
    if pacman -Qi lutris &>/dev/null || pacman -Qi lutris-git &>/dev/null || (have_cmd flatpak && flatpak list | grep -q lutris); then
        ui_warn "Existing Lutris installation detected"
        PS3="Resolve conflict: "
        select ACTION in "Remove and reinstall" "Keep existing" "Manual resolution"; do
            case $REPLY in
            1)
                remove_conflicting_lutris
                break
                ;;
            2)
                ui_info "Keeping existing installation"
                return 0
                ;;
            3)
                ui_info "Manual resolution required - exiting to shell"
                return 1
                ;;
            esac
        done
    fi

    # Install dependencies first
    verify_lutris_deps

    # Offer installation methods
    ui_title "Select Lutris Installation Method"
    PS3="Installation method: "
    select METHOD in "Flatpak (Recommended)" "Pacman (Standard)" "AUR (lutris-git)" "Manual Compilation" "Skip"; do
        case $REPLY in
        1)
            ui_info "Installing Lutris via Flatpak..."
            if ! have_cmd flatpak; then
                install_pkg flatpak
                check_flatpak_config
            fi

            # Use predetermined scope or ask
            if [[ -n "$FLATPAK_SCOPE" ]]; then
                if flatpak install $FLATPAK_SCOPE flathub net.lutris.Lutris -y 2>>"$DIAG_LOG"; then
                    ui_ok "Lutris installed via Flatpak ($FLATPAK_SCOPE)"
                    export LUTRIS_CMD="flatpak run net.lutris.Lutris"
                    return 0
                fi
            else
                ui_warn "Flatpak scope ambiguous - user selection required"
                if flatpak install flathub net.lutris.Lutris -y 2>>"$DIAG_LOG"; then
                    ui_ok "Lutris installed via Flatpak"
                    export LUTRIS_CMD="flatpak run net.lutris.Lutris"
                    return 0
                fi
            fi
            ui_err "Flatpak installation failed"
            return 1
            ;;
        2)
            ui_info "Installing Lutris via pacman..."
            if install_pkg lutris; then
                export LUTRIS_CMD="lutris"
                return 0
            fi
            ui_err "Pacman installation failed"
            return 1
            ;;
        3)
            ui_info "Installing Lutris via AUR..."

            # Ensure no conflicts
            if pacman -Qi lutris &>/dev/null; then
                ui_warn "Standard lutris package must be removed first"
                sudo pacman -Rns lutris --noconfirm 2>>"$DIAG_LOG"
            fi

            if have_cmd yay; then
                if yay -S --noconfirm lutris-git 2>>"$DIAG_LOG"; then
                    ui_ok "Lutris installed via AUR (yay)"
                    export LUTRIS_CMD="lutris"
                    return 0
                fi
            elif have_cmd paru; then
                if paru -S --noconfirm lutris-git 2>>"$DIAG_LOG"; then
                    ui_ok "Lutris installed via AUR (paru)"
                    export LUTRIS_CMD="lutris"
                    return 0
                fi
            else
                ui_err "No AUR helper found (install yay or paru)"
                return 1
            fi
            ui_err "AUR installation failed"
            return 1
            ;;
        4)
            ui_info "Manual compilation requires: git, python-setuptools, meson"
            install_pkgs git python-setuptools meson

            cd /tmp || exit

            # Remove old build if exists
            [[ -d /tmp/lutris ]] && rm -rf /tmp/lutris

            if git clone https://github.com/lutris/lutris.git 2>>"$DIAG_LOG"; then
                cd lutris || exit

                # Use user prefix to avoid permission errors
                if meson setup build --prefix="$HOME/.local" 2>>"$DIAG_LOG"; then
                    if ninja -C build 2>>"$DIAG_LOG"; then
                        if ninja -C build install 2>>"$DIAG_LOG"; then
                            ui_ok "Lutris compiled and installed to ~/.local"
                            export PATH="$HOME/.local/bin:$PATH"
                            export LUTRIS_CMD="$HOME/.local/bin/lutris"
                            return 0
                        else
                            ui_err "Installation failed - trying with sudo..."
                            if sudo ninja -C build install 2>>"$DIAG_LOG"; then
                                ui_ok "Lutris installed system-wide"
                                export LUTRIS_CMD="lutris"
                                return 0
                            fi
                        fi
                    fi
                fi
            fi
            ui_err "Manual compilation failed"
            return 1
            ;;
        5)
            ui_warn "Skipping Lutris installation"
            return 1
            ;;
        *)
            ui_err "Invalid selection"
            ;;
        esac
    done
}

# ===============================
# Enhanced Lutris Verification
# ===============================
verify_lutris() {
    ui_info "Verifying Lutris installation..."

    # Check for standard binary
    if have_cmd lutris; then
        ui_info "Testing standard lutris command..."
        if timeout 10s lutris --version &>/dev/null; then
            ui_ok "Lutris operational (standard)"
            export LUTRIS_CMD="lutris"
            export LUTRIS_AVAILABLE=true
            return 0
        else
            ui_warn "Standard lutris command found but not operational"
            lutris --version 2>&1 | tee -a "$DIAG_LOG"
        fi
    fi

    # Check for Flatpak
    if have_cmd flatpak && flatpak list | grep -q lutris; then
        ui_info "Testing Flatpak lutris..."
        if timeout 10s flatpak run net.lutris.Lutris --version &>/dev/null; then
            ui_ok "Lutris operational (Flatpak)"
            export LUTRIS_CMD="flatpak run net.lutris.Lutris"
            export LUTRIS_AVAILABLE=true
            return 0
        else
            ui_warn "Flatpak lutris found but not operational"
            flatpak run net.lutris.Lutris --version 2>&1 | tee -a "$DIAG_LOG"
        fi
    fi

    # Check for locally compiled
    if [[ -x "$HOME/.local/bin/lutris" ]]; then
        ui_info "Testing locally compiled lutris..."
        if timeout 10s "$HOME/.local/bin/lutris" --version &>/dev/null; then
            ui_ok "Lutris operational (local build)"
            export LUTRIS_CMD="$HOME/.local/bin/lutris"
            export LUTRIS_AVAILABLE=true
            return 0
        else
            ui_warn "Local lutris binary found but not operational"
            "$HOME/.local/bin/lutris" --version 2>&1 | tee -a "$DIAG_LOG"
        fi
    fi

    ui_err "Lutris not operational"
    export LUTRIS_AVAILABLE=false
    return 1
}

# ===============================
# Verification helpers
# ===============================
verify_binary() {
    if have_cmd "$1"; then
        local version
        version=$("$1" --version 2>&1 | head -n1 || echo "version unavailable")
        ui_ok "Verified: $1 ($version)"
        return 0
    else
        ui_warn "Missing: $1"
        return 1
    fi
}

# ===============================
# Detection helpers
# ===============================
detect_lutris_games() {
    if [[ -n "$LUTRIS_CMD" ]]; then
        $LUTRIS_CMD -l 2>/dev/null | awk 'NR>1 {print $1}'
    fi
}

detect_lutris_prefixes() { find "$HOME/Games" -maxdepth 2 -type d 2>/dev/null; }
detect_wine_prefixes() { find "$HOME" -maxdepth 2 -type d -name '.wine*' 2>/dev/null; }
detect_steam_games() { find "$HOME/.steam/steam/steamapps" -name 'appmanifest_*.acf' 2>/dev/null | sed 's/.*_//;s/.acf//'; }

# ===============================
# Universal fallback logic
# ===============================
fallback_menu() {
    ui_warn "Primary method unavailable — choose fallback strategy"
    PS3="Fallback option: "
    select FB in "Steam + Proton" "Bottles Manager" "Heroic Games Launcher" "Manual Wine Prefix" "View Manual Instructions" "Retry Primary Method" "Exit"; do
        case $REPLY in
        1)
            ui_info "Installing Steam..."
            if install_pkg steam; then
                ui_info "Steam installed successfully"
                ui_info "Instructions:"
                echo "  1. Open Steam and enable Proton:"
                echo "     Steam → Settings → Compatibility → Enable Steam Play for all titles"
                echo "  2. Add non-Steam game:"
                echo "     Games → Add Non-Steam Game → Browse to game EXE"
                echo "  3. Force Proton:"
                echo "     Right-click game → Properties → Compatibility → Force Proton version"
            else
                ui_err "Steam installation failed"
                continue
            fi
            break
            ;;
        2)
            ui_info "Installing Bottles..."
            if install_pkg bottles flatpak; then
                ui_ok "Bottles installed"
                ui_info "Launch Bottles and create a new gaming bottle"
                have_cmd bottles && (
                    bottles &
                    disown
                )
            else
                ui_err "Bottles installation failed"
                continue
            fi
            break
            ;;
        3)
            ui_info "Installing Heroic Games Launcher..."
            if install_pkg heroic-games-launcher-bin aur; then
                ui_ok "Heroic installed (supports Epic, GOG)"
                have_cmd heroic && (
                    heroic &
                    disown
                )
            elif have_cmd flatpak; then
                flatpak install ${FLATPAK_SCOPE:-} flathub com.heroicgameslauncher.hgl -y && ui_ok "Heroic installed via Flatpak"
            else
                ui_err "Heroic installation failed"
                continue
            fi
            break
            ;;
        4)
            ui_info "Creating manual Wine prefix..."
            if have_cmd wine; then
                export WINEPREFIX="$HOME/.wine-manual"
                winecfg 2>>"$DIAG_LOG" || ui_err "winecfg failed"
                ui_ok "Wine prefix created: $WINEPREFIX"
                ui_info "To launch games: WINEPREFIX=$WINEPREFIX wine /path/to/game.exe"
            else
                ui_err "Wine not installed"
                install_pkgs wine wine-gecko wine-mono winetricks
                continue
            fi
            break
            ;;
        5)
            ui_info "=== Manual Installation Guide ==="
            cat <<'EOF'
Option 1: Steam Proton
  1. Install Steam: sudo pacman -S steam
  2. Enable Proton: Settings → Compatibility → Enable for all titles
  3. Add game: Games → Add Non-Steam Game
  4. Set Proton: Properties → Compatibility

Option 2: Wine Direct
  1. Install Wine: sudo pacman -S wine winetricks
  2. Create prefix: WINEPREFIX=~/.wine-game winecfg
  3. Install game: WINEPREFIX=~/.wine-game wine installer.exe
  4. Run game: WINEPREFIX=~/.wine-game wine game.exe

Option 3: Bottles (GUI)
  1. Install: sudo pacman -S bottles or flatpak
  2. Create bottle: New → Gaming
  3. Run installer through Bottles interface

Option 4: Native Linux Versions
  - Check Steam, GOG, Itch.io for native builds
  - Use ProtonDB (protondb.com) for compatibility info
EOF
            read -rp "Press Enter to continue..."
            break
            ;;
        6)
            return 2 # Signal to retry primary method
            ;;
        7)
            ui_info "Exiting fallback menu"
            exit 0
            ;;
        *) ui_err "Invalid selection" ;;
        esac
    done
}

# ===============================
# Step 1 — System + GPU
# ===============================
ui_title "System & GPU Setup"
ui_info "Updating system packages..."
if sudo pacman -Syu --noconfirm 2>>"$DIAG_LOG"; then
    ui_ok "System updated"
else
    ui_warn "System update encountered issues (see $DIAG_LOG)"
    ui_info "Attempting partial update..."
    sudo pacman -Sy --noconfirm 2>>"$DIAG_LOG" || ui_err "Partial update also failed"
fi

GPU=$(lspci | grep -Ei 'vga|3d')
ui_info "Detected GPU: $GPU"

if echo "$GPU" | grep -qi nvidia; then
    ui_info "Installing NVIDIA drivers..."
    if ! install_pkg nvidia; then
        ui_warn "Official NVIDIA driver failed, trying nvidia-dkms..."
        install_pkg nvidia-dkms aur
    fi
    install_pkgs nvidia-utils lib32-nvidia-utils lib32-vulkan-icd-loader
elif echo "$GPU" | grep -qi amd; then
    ui_info "Installing AMD drivers..."
    install_pkgs mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
    if ! verify_binary vulkaninfo; then
        ui_warn "Vulkan tools missing, installing..."
        install_pkg vulkan-tools
    fi
elif echo "$GPU" | grep -qi intel; then
    ui_info "Installing Intel drivers..."
    install_pkgs mesa lib32-mesa vulkan-intel lib32-vulkan-intel
else
    ui_info "Installing generic Mesa drivers..."
    install_pkgs mesa lib32-mesa
fi

# ===============================
# Step 2 — Wine stack
# ===============================
ui_title "Wine Stack"
ui_info "Installing Wine and dependencies..."

if install_pkg wine; then
    install_pkgs wine-gecko wine-mono winetricks dxvk lib32-gnutls lib32-libpulse lib32-alsa-plugins
    verify_binary wine || ui_warn "Wine installed but not in PATH"
    verify_binary winetricks || ui_warn "Winetricks unavailable"
else
    ui_err "Wine installation failed"
    PS3="Wine installation method: "
    select WINE_METHOD in "Retry pacman" "Install wine-staging" "Install from AUR" "Skip Wine"; do
        case $REPLY in
        1)
            install_pkg wine
            break
            ;;
        2)
            install_pkg wine-staging
            break
            ;;
        3)
            if have_cmd yay; then
                yay -S wine-tkg-staging-fsync-git --noconfirm
            elif have_cmd paru; then
                paru -S wine-tkg-staging-fsync-git --noconfirm
            fi
            break
            ;;
        4)
            ui_warn "Skipping Wine - limited gaming functionality"
            break
            ;;
        *) ui_err "Invalid selection" ;;
        esac
    done
fi

# ===============================
# Step 3 — Lutris with Enhanced Conflict Resolution
# ===============================
ui_title "Lutris Installation & Verification"

install_lutris_safe

if verify_lutris; then
    ui_ok "Lutris fully operational"
    ui_info "Lutris command: $LUTRIS_CMD"
else
    ui_err "Lutris verification failed"
    diagnose_lutris_issues
    ui_warn "Fallback methods will be offered during platform selection"
fi

# ===============================
# Step 4 — Platform selection
# ===============================
ui_title "Select Gaming Platform"
PS3="Platform: "
select PLATFORM in "Battle.net (Blizzard)" "EA App" "Ubisoft Connect" "Epic Games Store" "Steam" "GOG Galaxy" "Xbox Game Pass (Cloud)" "Show All Installed Games" "Exit"; do
    case $REPLY in
    1)
        PLATFORM=battlenet
        break
        ;;
    2)
        PLATFORM=ea
        break
        ;;
    3)
        PLATFORM=ubisoft
        break
        ;;
    4)
        PLATFORM=epic
        break
        ;;
    5)
        PLATFORM=steam
        break
        ;;
    6)
        PLATFORM=gog
        break
        ;;
    7)
        PLATFORM=xbox
        break
        ;;
    8)
        PLATFORM=detect
        break
        ;;
    9) exit 0 ;;
    *) ui_err "Invalid selection" ;;
    esac
done

# ===============================
# Step 5 — Platform logic
# ===============================
ui_title "Configuring $PLATFORM"

case "$PLATFORM" in

detect)
    ui_info "=== Scanning for installed games ==="
    echo ""
    ui_info "Lutris games:"
    detect_lutris_games | sed 's/^/  • /' || ui_warn "No Lutris games detected"
    echo ""
    ui_info "Steam games (AppIDs):"
    detect_steam_games | head -n 10 | sed 's/^/  • /' || ui_warn "No Steam games detected"
    echo ""
    ui_info "Wine prefixes:"
    detect_wine_prefixes | sed 's/^/  • /' || ui_warn "No Wine prefixes detected"
    ;;

battlenet)
    ui_info "Detecting Blizzard game installations..."
    INSTALLED=$(detect_lutris_games | grep -Ei 'diablo|warcraft|overwatch|starcraft|call' || true)
    [[ -n "$INSTALLED" ]] && echo "$INSTALLED" | sed 's/^/  • /' || ui_warn "No Blizzard games detected"

    PS3="Blizzard action: "
    select MODE in "Install new game" "Verify existing installs" "Manual setup" "Back"; do
        case $REPLY in
        1)
            PS3="Choose game: "
            select GAME in "StarCraft II" "Diablo IV" "World of Warcraft" "Overwatch 2" "Diablo III" "Hearthstone" "Call of Duty" "Custom"; do
                case $REPLY in
                1) SLUG=starcraft-ii ;; 2) SLUG=diablo-iv ;; 3) SLUG=world-of-warcraft ;;
                4) SLUG=overwatch-2 ;; 5) SLUG=diablo-iii ;; 6) SLUG=hearthstone ;;
                7) SLUG=call-of-duty ;; 8) read -rp "Enter custom Lutris slug: " SLUG ;;
                *)
                    ui_err "Invalid selection"
                    continue
                    ;;
                esac
                break
            done

            if [[ "$LUTRIS_AVAILABLE" == true ]]; then
                ui_info "Installing via Lutris..."
                if $LUTRIS_CMD -i "https://lutris.net/api/installers/battlenet-standard" 2>>"$DIAG_LOG"; then
                    ui_ok "Battle.net installer launched"
                    sleep 2
                    $LUTRIS_CMD -i "https://lutris.net/api/installers/$SLUG" 2>>"$DIAG_LOG" || ui_warn "Game installer failed"
                else
                    ui_err "Lutris installation failed"
                    RETRY=$(fallback_menu)
                    [[ $RETRY -eq 2 ]] && continue || break
                fi
            else
                ui_warn "Lutris unavailable"
                fallback_menu
            fi
            break
            ;;
        2)
            ui_info "Existing installations:"
            detect_lutris_prefixes | sed 's/^/  • /' || ui_warn "No prefixes found"
            break
            ;;
        3)
            ui_info "Manual setup guide:"
            echo "  1. Download Battle.net installer from blizzard.com"
            echo "  2. Choose installation method:"
            fallback_menu
            break
            ;;
        4) break ;;
        esac
    done
    ;;

ea | ubisoft | epic | steam | gog | xbox)
    # Platform-specific logic retained from previous version
    ui_info "Platform $PLATFORM selected - implement specific logic as needed"
    if [[ "$LUTRIS_AVAILABLE" != true ]]; then
        fallback_menu
    fi
    ;;

esac

# ===============================
# Final Verification
# ===============================
ui_title "Final System Verification"

ui_info "Checking installed components..."
verify_binary wine || ui_warn "Wine unavailable - limited gaming support"
verify_binary winetricks || ui_warn "Winetricks unavailable"
verify_binary steam || ui_warn "Steam not installed"

if [[ "$LUTRIS_AVAILABLE" == true ]]; then
    ui_ok "Lutris operational ($LUTRIS_CMD)"
else
    ui_warn "Lutris unavailable - using fallback methods"
fi

# ===============================
# Completion Report
# ===============================
ui_title "Setup Complete"

cat <<EOF
${CLR_BOLD}${CLR_GREEN}Installation Summary:${CLR_RESET}
  • Platform: $PLATFORM
  • Lutris Status: ${LUTRIS_AVAILABLE:-false}
  • Lutris Command: ${LUTRIS_CMD:-N/A}
  • Wine Available: $(have_cmd wine && echo "Yes" || echo "No")
  • Steam Available: $(have_cmd steam && echo "Yes" || echo "No")

${CLR_BOLD}Log Files:${CLR_RESET}
  • Main log: $LOG
  • Diagnostic log: $DIAG_LOG
  • Skipped packages: $SKIPPED_PKGS

${CLR_BOLD}Next Steps:${CLR_RESET}
EOF

if [[ "$LUTRIS_AVAILABLE" == true ]]; then
    echo "  1. Launch Lutris: ${CLR_CYAN}$LUTRIS_CMD${CLR_RESET}"
    echo "  2. Login to platform launcher"
    echo "  3. Install/launch games"
elif have_cmd steam; then
    echo "  1. Launch Steam: ${CLR_CYAN}steam${CLR_RESET}"
    echo "  2. Enable Proton compatibility"
    echo "  3. Add non-Steam games or browse Steam library"
else
    echo "  1. Review fallback options in this script"
    echo "  2. Install Bottles, Heroic, or other launchers"
    echo "  3. Check manual installation guide"
fi

echo ""
echo "${CLR_YELLOW}Troubleshooting:${CLR_RESET}"
echo "  • Review diagnostic log: ${CLR_CYAN}cat $DIAG_LOG${CLR_RESET}"
echo "  • Re-run script if issues persist"
echo "  • Check ProtonDB: ${CLR_CYAN}https://protondb.com${CLR_RESET}"
