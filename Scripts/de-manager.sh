#!/usr/bin/env bash
# Desktop Environment Manager – Full GUI + CLI Hybrid
# Version: 3.2-final (syntax fixed)
# Requires: yad (optional), standard Linux tools

set -euo pipefail
IFS=$'\n\t'

# ── Package Manager Detection ────────────────────────────────────────
detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "deb"
    elif command -v dnf >/dev/null 2>&1; then
        echo "rpm"
    elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
    elif command -v zypper >/dev/null 2>&1; then
        echo "suse"
    elif command -v xbps-install >/dev/null 2>&1; then
        echo "void"
    else echo "unknown"; fi
}
PKG_SYS=$(detect_pkg_manager)

# ── GUI Detection & Colors ───────────────────────────────────────────
if [[ -t 1 ]] && command -v yad >/dev/null 2>&1; then
    HAS_GUI=1
else
    HAS_GUI=0
    RED='\033[0;31m' GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[1;33m' NC='\033[0m'
fi

# ── Output Helpers ───────────────────────────────────────────────────
info() { [[ $HAS_GUI -eq 1 ]] && yad --info --title="Info" --text="$*" --width=500 || printf "${GREEN}✓ %s${NC}\n" "$*"; }
error() { [[ $HAS_GUI -eq 1 ]] && yad --error --text="$*" || printf "${RED}✗ %s${NC}\n" "$*" >&2; }
warn() { [[ $HAS_GUI -eq 1 ]] && yad --warning --text="$*" || printf "${YELLOW}! %s${NC}\n" "$*" >&2; }
progress() { yad --progress --pulsate --auto-close --text="$1" --width=450 --title="Working..." --no-buttons; }

# ── Detect Current Session ───────────────────────────────────────────
detect_current() {
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        echo "$XDG_CURRENT_DESKTOP"
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        echo "$DESKTOP_SESSION"
    elif [[ -n "${GDMSESSION:-}" ]]; then
        echo "$GDMSESSION"
    elif command -v loginctl >/dev/null 2>&1; then
        session=$(loginctl list-sessions --no-legend | awk 'NR==1 {print $1}' 2>/dev/null || echo "")
        type=$(loginctl show-session "$session" -p Type --value 2>/dev/null || echo "unknown")
        [[ "$type" == "wayland" ]] && echo "Wayland" || echo "X11"
    else
        echo "Unknown"
    fi
}

# ── List All Available Sessions ──────────────────────────────────────
list_sessions() {
    local paths=(
        "/usr/share/xsessions" "/usr/share/wayland-sessions"
        "/usr/local/share/xsessions" "/usr/local/share/wayland-sessions"
        "$HOME/.local/share/xsessions" "$HOME/.local/share/wayland-sessions"
    )

    find "${paths[@]}" -type f -name "*.desktop" 2>/dev/null | sort |
        while IFS= read -r file; do
            name=$(grep -m1 "^Name=" "$file" | cut -d= -f2- | sed 's/^\s*//;s/\s*$//')
            [[ -z "$name" ]] && name="Unnamed Session"
            printf "%s\n" "$name"
        done
}

# ── Backup Configurations (Compressed) ───────────────────────────────
backup_configs() {
    local backup_dir="$HOME/de-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    local patterns=(
        .config/{plasma*,kde*,gnome*,xfce*,cinnamon,mate,lxqt}
        .config/{i3,sway,hypr,wayfire,qtile,bspwm,awesome,openbox,dwm}
        .config/{niri,river,leftwm,herbstluftwm}
    )

    local found=0
    for pattern in "${patterns[@]}"; do
        shopt -s nullglob
        for dir in ~/$pattern; do
            [[ -d "$dir" ]] || continue
            found=1
            local base=$(basename "$dir")
            info "Backing up $base..."
            tar -czf "$backup_dir/$base.tar.gz" \
                -C "$HOME" \
                --exclude="Cache" --exclude="cache" --exclude="*.cache" \
                "$dir" >/dev/null 2>&1 || warn "Partial backup for $base"
        done
        shopt -u nullglob
    done

    [[ $found -eq 0 ]] && warn "No known config directories found"
    info "Backup completed:\n$backup_dir"
}

# ── Memory Usage (Accurate RSS via /proc) ─────────────────────────────
memory_usage() {
    local current=$(detect_current | tr '[:upper:]' '[:lower:]')
    local pids=()

    case "$current" in
    *gnome*) pids+=($(pgrep -f gnome-shell) $(pgrep -f mutter) $(pgrep -f gdm)) ;;
    *plasma* | *kde*) pids+=($(pgrep -f plasmashell) $(pgrep -f kwin)) ;;
    *xfce*) pids+=($(pgrep -f xfce4-session) $(pgrep -f xfwm4)) ;;
    *mate*) pids+=($(pgrep -f mate-session)) ;;
    *cinnamon*) pids+=($(pgrep -f cinnamon)) ;;
    *lxqt*) pids+=($(pgrep -f lxqt-session)) ;;
    *i3*) pids+=($(pgrep -f i3)) ;;
    *sway*) pids+=($(pgrep -f sway)) ;;
    *hypr*) pids+=($(pgrep -f Hyprland)) ;;
    *wayland*) pids+=($(pgrep -f wlroots || echo)) ;;
    *)
        error "Unknown desktop environment: $current"
        return 1
        ;;
    esac

    local total_rss=0
    for pid in "${pids[@]}"; do
        [[ -z "$pid" ]] && continue
        if [[ -r "/proc/$pid/statm" ]]; then
            rss_pages=$(awk '{print $2}' "/proc/$pid/statm")
            ((total_rss += rss_pages * 4))
        fi
    done

    if [[ $total_rss -eq 0 ]]; then
        printf "No memory usage detected for %s\n" "$current"
    else
        printf "Memory Usage (%s): %.2f MB\n" "$current" "$(bc <<<"scale=2; $total_rss / 1024")"
    fi
}

# ── Reinstall Current DE/WM ───────────────────────────────────────────
reinstall_current() {
    local current=$(detect_current | tr '[:upper:]' '[:lower:]')
    local pkgs=()

    case "$current" in
    *gnome*) pkgs=(gnome-shell gdm3 ubuntu-gnome-desktop) ;;
    *plasma* | *kde*) pkgs=(plasma-desktop kde-standard) ;;
    *xfce*) pkgs=(xfce4 xfce4-goodies) ;;
    *cinnamon*) pkgs=(cinnamon cinnamon-desktop-environment) ;;
    *mate*) pkgs=(mate-desktop-environment) ;;
    *lxqt*) pkgs=(lxqt) ;;
    *)
        error "Reinstall not supported for: $current"
        return 1
        ;;
    esac

    info "Reinstalling packages for: $current\n\n${pkgs[*]}"
    case "$PKG_SYS" in
    deb) sudo apt-get install --reinstall -y "${pkgs[@]}" ;;
    rpm) sudo dnf reinstall -y "${pkgs[@]}" ;;
    arch) sudo pacman -S --noconfirm "${pkgs[@]}" ;;
    suse) sudo zypper install --force -y "${pkgs[@]}" ;;
    void) sudo xbps-install -S --reinstall "${pkgs[@]}" ;;
    *)
        error "Unsupported package manager"
        return 1
        ;;
    esac && info "Reinstall completed!"
}

# ── Uninstall Unused DEs (Safe Checklist) ─────────────────────────────
uninstall_unused() {
    local sessions=()
    while IFS= read -r s; do [[ -n "$s" ]] && sessions+=("FALSE" "$s"); done < <(list_sessions)

    local selected=$(yad --list --checklist --width=700 --height=500 \
        --title="Uninstall Unused Desktop Environments" \
        --text="Select environments to REMOVE (current session protected)" \
        --column="Remove" --column="Desktop Environment" \
        "${sessions[@]}" --separator=" " || echo "")

    [[ -z "$selected" ]] && return 0

    local current_name=$(detect_current)
    local pkgs_to_remove=()

    for env in $selected; do
        [[ "$env" == "$current_name" ]] && {
            warn "Skipping current session: $env"
            continue
        }
        case "$env" in
        *GNOME*) pkgs_to_remove+=(gnome-shell gdm3) ;;
        *Plasma* | *KDE*) pkgs_to_remove+=(plasma-desktop) ;;
        *XFCE*) pkgs_to_remove+=(xfce4) ;;
        *Cinnamon*) pkgs_to_remove+=(cinnamon) ;;
        *MATE*) pkgs_to_remove+=(mate-desktop-environment) ;;
        esac
    done

    if [[ ${#pkgs_to_remove[@]} -eq 0 ]]; then
        info "Nothing selected for removal."
        return 0
    fi

    yad --question --text="Remove ${#pkgs_to_remove[@]} packages?\n\nThis action is irreversible!" || return 0

    case "$PKG_SYS" in
    deb) sudo apt-get remove --purge -y "${pkgs_to_remove[@]}" ;;
    rpm) sudo dnf remove -y "${pkgs_to_remove[@]}" ;;
    arch) sudo pacman -Rns --noconfirm "${pkgs_to_remove[@]}" ;;
    *) error "Unsupported package manager" ;;
    esac && info "Uninstall completed."
}

# ── GUI Main Menu ────────────────────────────────────────────────────
show_gui() {
    while true; do
        choice=$(yad --width=600 --height=520 --title="Desktop Environment Manager" \
            --window-icon=preferences-desktop \
            --text="<big><b>Desktop Environment Manager</b></big>\nSelect an action:" \
            --list --column="Icon" --column="Action" --print-column=2 \
            "system-software-update" "Reinstall Current DE/WM" \
            "edit-delete" "Uninstall Unused DE/WM" \
            "document-save" "Backup All Configurations" \
            "utilities-system-monitor" "Show Memory Usage" \
            "dialog-information" "Show Current Session" \
            "help-about" "List All Sessions" \
            "application-exit" "Exit" \
            --button="Switch to CLI:2" --button="Close:0")

        ret=$?
        [[ $ret -eq 2 ]] && return 1
        [[ $ret -ne 0 ]] && exit 0

        case "$choice" in
        "Reinstall Current DE/WM") reinstall_current ;;
        "Uninstall Unused DE/WM") uninstall_unused ;;
        "Backup All Configurations") (backup_configs) | progress "Creating backup..." ;;
        "Show Memory Usage") memory_usage | yad --text-info --title="Memory Usage" --width=500 ;;
        "Show Current Session") yad --info --title="Current Session" --text="Current: $(detect_current)" ;;
        "List All Sessions") list_sessions | yad --text-info --title="Available Sessions" ;;
        "Exit") exit 0 ;;
        esac
    done
}

# ── CLI Fallback Menu ────────────────────────────────────────────────
show_cli_menu() {
    while true; do
        clear
        cat <<-EOF
		${BLUE}Desktop Environment Manager (CLI Mode)${NC}
		Current: $(detect_current)

		1) List available sessions
		2) Show current session
		3) Backup configurations
		4) Show memory usage
		5) Reinstall current DE/WM
		6) Uninstall unused DE/WM
		7) Exit

		Choice [1-7]:
		EOF

        read -r choice
        case "$choice" in
        1)
            list_sessions
            read -p "Press Enter to continue..."
            ;;
        2)
            echo "Current: $(detect_current)"
            read -p "Press Enter..."
            ;;
        3)
            backup_configs
            read -p "Press Enter..."
            ;;
        4)
            memory_usage
            read -p "Press Enter..."
            ;;
        5)
            reinstall_current
            read -p "Press Enter..."
            ;;
        6)
            uninstall_unused
            read -p "Press Enter..."
            ;;
        7) break ;;
        *) echo "Invalid choice" ;;
        esac
    done
}

# ── Main Entry Point ─────────────────────────────────────────────────
main() {
    if [[ $HAS_GUI -eq 1 && -z "${FORCE_CLI:-}" ]]; then
        show_gui || show_cli_menu
    else
        show_cli_menu
    fi
}

main "$@"
