#!/bin/bash

# =============================================================================
# System-Wide Update Manager v4.0 - Enhanced Edition (FIXED) with Topgrade Integration
# =============================================================================
# A comprehensive system update script for Arch-based distributions
# Features: Parallel updates, rollback capability, health monitoring,
#           notifications, progress persistence, and advanced error handling
#           Now integrated with Topgrade-inspired updates for firmware, Git, language managers, etc.
# =============================================================================

set -euo pipefail # Exit on error, undefined vars, pipe failures

# =============================================================================
# CONFIGURATION AND GLOBAL VARIABLES
# =============================================================================

# Enhanced configuration with environment support
CONFIG_DIR="$HOME/.config/update-manager"
BACKUP_DIR="$CONFIG_DIR/backups/$(date +%Y%m%d_%H%M%S)"
METRICS_DIR="$CONFIG_DIR/metrics"
JSON_LOG="$CONFIG_DIR/logs/updates.json"
PROGRESS_FILE="$CONFIG_DIR/progress.json"
ROLLBACK_DIR="$CONFIG_DIR/rollback"
NOTIFICATION_PID_FILE="$CONFIG_DIR/notification.pid"

# Create necessary directories
mkdir -p "$CONFIG_DIR"/{backups,metrics,logs,rollback}

# Enhanced configuration files to backup
IMPORTANT_CONFIGS=(
    "$HOME/.config/hypr"
    "$HOME/.config/kde"
    "$HOME/.config/environment.d"
    "$HOME/.config/plasma-workspace"
    "$HOME/.config/kwinrc"
    "$HOME/.config/waybar"
    "$HOME/.config/wlogout"
    "$HOME/.config/pipewire"
    "$HOME/.config/wireplumber"
    "/etc/X11/xorg.conf.d"
    "/etc/pacman.conf"
    "/etc/pacman.d"
    "/etc/makepkg.conf"
)

# Topgrade-inspired configurable lists
GIT_REPOS=(
    "$HOME/.emacs.d"
    "$HOME/.doom.d"
    "$HOME/.tmux"
    "$HOME/.zsh"
    "$HOME/.oh-my-zsh"
    "$HOME/.config/fish"
    "$HOME/.config/Code/User" # For VS Code settings
)

# NEW: Neovim plugins (assuming packer.nvim; customize as needed)
NEOVIM_PLUGINS=(
    "$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
)

# NEW: Tmux plugins (assuming tpm; customize paths)
TMUX_PLUGINS=(
    "$HOME/.tmux/plugins/tpm"
)

# NEW: Vim plugins (assuming vim-plug; customize)
VIM_PLUGINS=(
    "$HOME/.vim/autoload/plug.vim"
)

CUSTOM_COMMANDS=()

SHELL_UPDATES=(
    "oh-my-zsh" # Example, add more like fisher, prezto
)

# System information
SCRIPT_VERSION="4.0"
SCRIPT_NAME="System Update Manager"
START_TIME=""
START_EPOCH=0
END_TIME=""
TOTAL_PACKAGES_UPDATED=0
FAILED_OPERATIONS=0
ROLLBACK_ENABLED=false
PARALLEL_UPDATES=false
MAX_PARALLEL_JOBS=3

# Colors and styles
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'

# Modern UI Icons
ICON_CHECK="✓"
ICON_WARN="⚠️"
ICON_ERROR="❌"
ICON_PACKAGE="📦"
ICON_SYSTEM="🖥️"
ICON_BACKUP="💾"
ICON_UPDATE="🔄"
ICON_CLEANUP="🧹"
ICON_NETWORK="🌐"
ICON_CONFIG="⚙️"
ICON_GPU="🎮"
ICON_DISK="💿"
ICON_DESKTOP="🖥️"
ICON_KERNEL="🐧"
ICON_COMPLETE="🎉"
ICON_FIRMWARE="🔧" # New for firmware
ICON_GIT="📚"      # New for Git
ICON_LANG="🛠️"    # New for language managers

# =============================================================================
# ENHANCED FLAGS AND DEFAULTS
# =============================================================================

# Core update flags
NONINTERACTIVE=0
SKIP_AUR=0
SKIP_FLATPAK=0
SKIP_SNAP=0
SKIP_CLEANUP=0
DRY_RUN=0
AUR_DEVEL=0
DNS_FALLBACK=0
ALLOW_DOWNGRADE=0
SNAPSHOT_TOOL=""
PACNEW_MANAGE=0
NO_COLOR=0
QUIET=0
VERBOSE=0
REPORT_PATH=""

# New Topgrade-inspired skip flags
SKIP_FIRMWARE=0
SKIP_GIT=0
SKIP_CARGO=0
SKIP_PIP=0
SKIP_NPM=0
SKIP_GEM=0
SKIP_COMPOSER=0
SKIP_SHELL=0
SKIP_VSCODE=0
SKIP_CUSTOM=0
# NEW: Additional skips
SKIP_HOMEBREW=0
SKIP_GO=0
SKIP_HASKELL=0
SKIP_LUA=0
SKIP_DOCKER=0
SKIP_NEOVIM=0
# NEW: More Topgrade and Guix skips
SKIP_NIX=0
SKIP_OPAM=0
SKIP_VCPKG=0
SKIP_YARN=0
SKIP_RUSTUP=0
SKIP_TMUX=0
SKIP_VIM=0
SKIP_STARSHIP=0
SKIP_GUIX=0

# Enhanced features
ENABLE_NOTIFICATIONS=0
NOTIFY_COMPLETE=0
NOTIFY_ERRORS=0
HEALTH_CHECK=0
MONITOR_RESOURCES=0
CHECK_DEPENDENCIES=0
FAST_MIRRORS=0
CONFIG_FILE=""
LOG_LEVEL="INFO"

# System state
SUDO_KEEPALIVE_PID=""
MIRROR_COUNTRY=""

# Distro detection
. /etc/os-release 2>/dev/null || true
case "${ID_LIKE:-$ID}" in
*manjaro* | *manjaro-linux*) DISTRO_BASE="manjaro" ;;
*) DISTRO_BASE="arch" ;;
esac

# =============================================================================
# ENHANCED ARGUMENT PARSING AND HELP SYSTEM
# =============================================================================

show_help() {
    cat <<EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

${BOLD}DESCRIPTION:${NC}
    A comprehensive system update manager for Arch-based distributions with
    advanced features including parallel updates, rollback capability,
    health monitoring, and desktop notifications. Now enhanced with Topgrade-inspired updates for firmware, Git repos, language managers, etc.

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    ${GREEN}Update Control:${NC}
        -y, --yes, --non-interactive    Run without user interaction
        --dry-run                       Show what would be updated without making changes
        --allow-downgrade               Allow package downgrades (pacman -Syud)
        --parallel                      Enable parallel updates (experimental)
        --max-jobs N                    Maximum parallel jobs (default: 3)

    ${GREEN}Package Managers:${NC}
        --no-aur                        Skip AUR updates
        --no-flatpak                    Skip Flatpak updates
        --no-snap                       Skip Snap updates
        --aur-devel                     Include AUR development packages

    ${GREEN}Topgrade-Inspired Updates:${NC}
        --no-firmware                   Skip firmware updates (fwupdmgr)
        --no-git                        Skip Git repository pulls
        --no-cargo                      Skip Cargo (Rust) updates
        --no-pip                        Skip Pip (Python) updates
        --no-npm                        Skip Npm (Node) global updates
        --no-gem                        Skip Gem (Ruby) updates
        --no-composer                   Skip Composer (PHP) global updates
        --no-shell                      Skip shell configuration updates (oh-my-zsh, etc.)
        --no-vscode                     Skip VS Code extension updates
        --no-custom                     Skip custom commands
        # NEW: Additional Topgrade handlers
        --no-homebrew                   Skip Homebrew (Linuxbrew) updates
        --no-go                         Skip Go module updates
        --no-haskell                    Skip Haskell (stack/ghcup) updates
        --no-lua                        Skip Lua (luarocks) updates
        --no-docker                     Skip Docker/Podman image updates
        --no-neovim                     Skip Neovim plugin updates
        # NEW: More Topgrade handlers
        --no-nix                        Skip Nix/Lix updates
        --no-opam                       Skip Opam (OCaml) updates
        --no-vcpkg                      Skip Vcpkg (C++) updates
        --no-yarn                       Skip Yarn (Node) updates
        --no-rustup                     Skip Rustup toolchain updates
        --no-tmux                       Skip Tmux plugin updates
        --no-vim                        Skip Vim plugin updates
        --no-starship                   Skip Starship prompt updates
        --no-guix                       Skip Guix package updates

    ${GREEN}System Operations:${NC}
        --no-cleanup                    Skip system cleanup
        --rollback                      Enable rollback capability
        --snapshots TOOL                Use snapshot tool (timeshift|snapper)
        --pacnew-manage                 Manage .pacnew/.pacsave files

    ${GREEN}Network & Mirrors:${NC}
        --dns-fallback                  Use fallback DNS servers
        --mirror-country COUNTRY       Set mirror country
        --fast-mirrors                  Use fastest mirrors

    ${GREEN}Output & Logging:${NC}
        --quiet                         Suppress output
        --verbose                       Verbose output
        --no-color                      Disable colored output
        --report FILE                   Generate report file
        --log-level LEVEL              Set log level (DEBUG|INFO|WARN|ERROR)

    ${GREEN}Notifications:${NC}
        --notify                        Enable desktop notifications
        --notify-complete               Notify on completion
        --notify-errors                 Notify on errors only

    ${GREEN}Health & Monitoring:${NC}
        --health-check                  Perform comprehensive health check
        --monitor-resources             Monitor system resources during update
        --check-dependencies            Verify package dependencies

    ${GREEN}Miscellaneous:${NC}
        -h, --help                      Show this help message
        --version                       Show version information
        --config FILE                   Use custom config file

${BOLD}EXAMPLES:${NC}
    $0 --parallel --notify              # Parallel updates with notifications
    $0 --dry-run --verbose             # Preview updates with verbose output
    $0 --rollback --health-check       # Update with rollback and health check
    $0 --allow-downgrade               # Allow package downgrades (for version conflicts)
    $0 --no-aur --fast-mirrors         # Skip AUR, use fast mirrors
    $0 --no-firmware --no-git          # Skip firmware and Git updates
    # NEW: Example with additional handlers
    $0 --no-homebrew --no-go           # Skip Homebrew and Go updates
    $0 --no-nix --no-guix              # Skip Nix and Guix updates

${BOLD}CONFIGURATION:${NC}
    Configuration files are stored in: $CONFIG_DIR
    Logs are stored in: $CONFIG_DIR/logs
    Backups are stored in: $CONFIG_DIR/backups
    Customize GIT_REPOS, NEOVIM_PLUGINS, TMUX_PLUGINS, VIM_PLUGINS, and CUSTOM_COMMANDS in the script for Topgrade-like behavior.

EOF
}

show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    echo "Enhanced system update manager for Arch-based distributions with Topgrade integration"
}

# Enhanced argument parsing with validation
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        --version)
            show_version
            exit 0
            ;;
        -y | --yes | --non-interactive) NONINTERACTIVE=1 ;;
        --no-aur) SKIP_AUR=1 ;;
        --no-flatpak) SKIP_FLATPAK=1 ;;
        --no-snap) SKIP_SNAP=1 ;;
        --no-cleanup) SKIP_CLEANUP=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --allow-downgrade) ALLOW_DOWNGRADE=1 ;;
        --aur-devel) AUR_DEVEL=1 ;;
        --dns-fallback) DNS_FALLBACK=1 ;;
        --parallel) PARALLEL_UPDATES=true ;;
        --max-jobs)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: Missing value for --max-jobs" >&2
                exit 1
            fi
            if ! [[ "$1" =~ ^[0-9]+$ ]]; then
                echo "Error: --max-jobs value must be a positive integer" >&2
                exit 1
            fi
            MAX_PARALLEL_JOBS="$1"
            ;;
        --rollback) ROLLBACK_ENABLED=true ;;
        --snapshots)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: Missing value for --snapshots" >&2
                exit 1
            fi
            SNAPSHOT_TOOL="$1"
            ;;
        --pacnew-manage) PACNEW_MANAGE=1 ;;
        --no-color) NO_COLOR=1 ;;
        --mirror-country)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: Missing value for --mirror-country" >&2
                exit 1
            fi
            MIRROR_COUNTRY="$1"
            ;;
        --fast-mirrors) FAST_MIRRORS=1 ;;
        --quiet) QUIET=1 ;;
        --verbose) VERBOSE=1 ;;
        --report)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: Missing value for --report" >&2
                exit 1
            fi
            REPORT_PATH="$1"
            ;;
        --notify) ENABLE_NOTIFICATIONS=1 ;;
        --notify-complete) NOTIFY_COMPLETE=1 ;;
        --notify-errors) NOTIFY_ERRORS=1 ;;
        --health-check) HEALTH_CHECK=1 ;;
        --monitor-resources) MONITOR_RESOURCES=1 ;;
        --check-dependencies) CHECK_DEPENDENCIES=1 ;;
        --log-level)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: Missing value for --log-level" >&2
                exit 1
            fi
            LOG_LEVEL="$1"
            ;;
        --config)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: Missing value for --config" >&2
                exit 1
            fi
            CONFIG_FILE="$1"
            ;;
        --no-firmware) SKIP_FIRMWARE=1 ;;
        --no-git) SKIP_GIT=1 ;;
        --no-cargo) SKIP_CARGO=1 ;;
        --no-pip) SKIP_PIP=1 ;;
        --no-npm) SKIP_NPM=1 ;;
        --no-gem) SKIP_GEM=1 ;;
        --no-composer) SKIP_COMPOSER=1 ;;
        --no-shell) SKIP_SHELL=1 ;;
        --no-vscode) SKIP_VSCODE=1 ;;
        --no-custom) SKIP_CUSTOM=1 ;;
        # NEW: Additional skip options
        --no-homebrew) SKIP_HOMEBREW=1 ;;
        --no-go) SKIP_GO=1 ;;
        --no-haskell) SKIP_HASKELL=1 ;;
        --no-lua) SKIP_LUA=1 ;;
        --no-docker) SKIP_DOCKER=1 ;;
        --no-neovim) SKIP_NEOVIM=1 ;;
        # NEW: More Topgrade and Guix skip options
        --no-nix) SKIP_NIX=1 ;;
        --no-opam) SKIP_OPAM=1 ;;
        --no-vcpkg) SKIP_VCPKG=1 ;;
        --no-yarn) SKIP_YARN=1 ;;
        --no-rustup) SKIP_RUSTUP=1 ;;
        --no-tmux) SKIP_TMUX=1 ;;
        --no-vim) SKIP_VIM=1 ;;
        --no-starship) SKIP_STARSHIP=1 ;;
        --no-guix) SKIP_GUIX=1 ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        esac
        shift
    done
}

parse_args "$@"

if [ "$NO_COLOR" -eq 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    BOLD=''
    DIM=''
    ITALIC=''
    NC=''
fi

# =============================================================================
# ENHANCED LOGGING SYSTEM
# =============================================================================

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$CONFIG_DIR/logs/update_${TIMESTAMP}.log"
ERROR_LOG="$CONFIG_DIR/logs/errors_${TIMESTAMP}.log"
BACKUP_LOG="$CONFIG_DIR/logs/backup_${TIMESTAMP}.log"
AUDIT_LOG="$CONFIG_DIR/logs/audit_${TIMESTAMP}.log"

touch "$LOG_FILE" "$ERROR_LOG" "$BACKUP_LOG" "$AUDIT_LOG"

v_echo() {
    [ "$QUIET" -eq 0 ] && echo -e "$1"
}

should_log() {
    local level="$1"
    case "$LOG_LEVEL" in
    "DEBUG") return 0 ;;
    "INFO") [ "$level" != "DEBUG" ] && return 0 ;;
    "WARN") [ "$level" = "WARN" ] || [ "$level" = "ERROR" ] && return 0 ;;
    "ERROR") [ "$level" = "ERROR" ] && return 0 ;;
    esac
    return 1
}

log_message() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local component="${3:-system}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    should_log "$level" || return 0

    case "$level" in
    "DEBUG") echo -e "${DIM}[DEBUG]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
    "INFO") echo -e "${GREEN}[INFO]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
    "WARN") echo -e "${YELLOW}[WARN]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
    "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" | tee -a "$ERROR_LOG" ;;
    "AUDIT") echo -e "${BLUE}[AUDIT]${NC} $timestamp - $message" | tee -a "$AUDIT_LOG" ;;
    *) echo -e "$timestamp - $message" | tee -a "$LOG_FILE" ;;
    esac

    mkdir -p "$(dirname "$JSON_LOG")"
    local json_entry=$(printf '{"timestamp":"%s","level":"%s","component":"%s","message":"%s","pid":"%s","user":"%s"}\n' \
        "$timestamp" "$level" "$component" "$message" "$$" "$USER")
    echo "$json_entry" >>"$JSON_LOG"

    update_progress "$level" "$message" "$component"
}

log_info() { log_message "INFO" "$1" "${2:-system}"; }
log_warn() { log_message "WARN" "$1" "${2:-system}"; }
log_error() { log_message "ERROR" "$1" "${2:-system}"; }
log_debug() { log_message "DEBUG" "$1" "${2:-system}"; }
log_audit() { log_message "AUDIT" "$1" "${2:-system}"; }

# =============================================================================
# ENHANCED UTILITY FUNCTIONS
# =============================================================================

update_progress() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local component="${3:-system}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local progress_data=$(
        cat <<EOF
{
    "timestamp": "$timestamp",
    "level": "$level",
    "component": "$component",
    "message": "$message",
    "total_packages": $TOTAL_PACKAGES_UPDATED,
    "failed_operations": $FAILED_OPERATIONS,
    "start_time": "$START_TIME",
    "current_time": "$timestamp"
}
EOF
    )
    echo "$progress_data" >"$PROGRESS_FILE"
}

send_notification() {
    local title="${1:-Update}"
    local message="${2:-}"
    local urgency="${3:-normal}"
    local icon="${4:-system-software-update}"

    [ "$ENABLE_NOTIFICATIONS" -eq 0 ] && return 0

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -i "$icon" "$title" "$message" &
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" --msgbox "$message" &
    elif command -v zenity >/dev/null 2>&1; then
        zenity --info --title "$title" --text "$message" &
    fi
}

handle_error_with_rollback() {
    local error_msg="${1:-Unknown error}"
    local error_code="${2:-1}"
    local component="${3:-system}"

    log_error "$error_msg (Code: $error_code)" "$component"
    ((FAILED_OPERATIONS++))

    [ "$NOTIFY_ERRORS" -eq 1 ] && send_notification "Update Error" "$error_msg" "critical" "error"

    if [ "$ROLLBACK_ENABLED" = true ] && [ -d "$ROLLBACK_DIR" ]; then
        log_info "Attempting rollback for component: $component" "$component"
        rollback_component "$component" || log_error "Rollback failed for $component" "$component"
    fi

    update_progress "ERROR" "$error_msg" "$component"
}

rollback_component() {
    local component="${1:-unknown}"
    local rollback_file="$ROLLBACK_DIR/${component}_backup.tar.gz"

    if [ -f "$rollback_file" ]; then
        log_info "Rolling back $component from $rollback_file" "$component"
        sudo tar -xzf "$rollback_file" -C / 2>/dev/null || return 1
        log_info "Successfully rolled back $component" "$component"
        return 0
    else
        log_warn "No rollback data found for $component" "$component"
        return 1
    fi
}

create_rollback_backup() {
    local component="${1:-unknown}"
    local rollback_file="$ROLLBACK_DIR/${component}_backup.tar.gz"

    mkdir -p "$ROLLBACK_DIR"

    case "$component" in
    "pacman")
        sudo tar -czf "$rollback_file" /var/lib/pacman/ 2>/dev/null || return 1
        ;;
    "config")
        tar -czf "$rollback_file" -C "$HOME" .config/ 2>/dev/null || return 1
        ;;
    # NEW: Extend for additional components
    "homebrew")
        sudo tar -czf "$rollback_file" /opt/homebrew/ 2>/dev/null || return 1 # Or /home/linuxbrew/.linuxbrew
        ;;
    "docker")
        sudo tar -czf "$rollback_file" /var/lib/docker/ 2>/dev/null || return 1
        ;;
    # NEW: More rollback cases
    "nix")
        tar -czf "$rollback_file" ~/.nix-profile 2>/dev/null || return 1
        ;;
    "guix")
        sudo tar -czf "$rollback_file" /gnu/store 2>/dev/null || log_warn "Guix store too large for full backup; skipping" && return 1
        ;;
    "opam")
        tar -czf "$rollback_file" ~/.opam 2>/dev/null || return 1
        ;;
    "vcpkg")
        tar -czf "$rollback_file" ~/.vcpkg 2>/dev/null || return 1
        ;;
    "tmux")
        tar -czf "$rollback_file" ~/.tmux 2>/dev/null || return 1
        ;;
    "vim")
        tar -czf "$rollback_file" ~/.vim 2>/dev/null || return 1
        ;;
    *)
        log_warn "Unknown component for rollback: $component" "$component"
        return 1
        ;;
    esac

    log_info "Created rollback backup for $component" "$component"
    return 0
}

cleanup_on_exit() {
    sudo rm -f /var/lib/pacman/db.lck 2>/dev/null || true
    if [ "$DNS_FALLBACK" = "1" ]; then
        if command -v resolvconf >/dev/null 2>&1; then
            resolvconf -d tmp-dns 2>/dev/null || true
        elif systemctl is-active systemd-resolved >/dev/null 2>&1; then
            sudo systemctl restart systemd-resolved 2>/dev/null || true
        fi
    fi
    rm -f /tmp/pacman_stderr.log 2>/dev/null || true
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true

    if [ "$NOTIFY_COMPLETE" -eq 1 ]; then
        send_notification "Update Complete" "System update finished with $TOTAL_PACKAGES_UPDATED packages updated" "normal" "system-software-update"
    fi
}
trap cleanup_on_exit EXIT INT TERM

start_sudo_keepalive() {
    if sudo -v; then
        (while true; do
            sudo -n true 2>/dev/null || exit
            sleep 60
        done) &
        SUDO_KEEPALIVE_PID=$!
    fi
}

retry() {
    local cmd="$1"
    local tries="${2:-3}"
    local backoff="${3:-2}"
    local i=1
    while [ $i -le $tries ]; do
        eval "$cmd" && return 0
        sleep $((backoff * i))
        i=$((i + 1))
    done
    return 1
}

check_command() {
    local cmd="${1:-}"
    [ -z "$cmd" ] && return 1
    if ! command -v "$cmd" &>/dev/null; then
        log_message "WARN" "Command not found: $cmd"
        return 1
    fi
    return 0
}

show_error_context() {
    local error_log="${1:-}"
    local context_lines="${2:-5}"

    if [ -n "$error_log" ] && [ -f "$error_log" ] && [ -s "$error_log" ]; then
        echo -e "${YELLOW}Error details:${NC}"
        tail -n "$context_lines" "$error_log" | sed 's/^/  /'
    fi
}

attempt_dependency_fix() {
    echo -e "\n${CYAN}${ICON_CONFIG} Attempting automatic dependency fixes...${NC}"
    log_info "Running automatic dependency troubleshooting" "pacman"

    local fix_applied=false

    # Step 1: Refresh package databases
    echo -e "${BLUE}  1/4 Refreshing package databases...${NC}"
    if sudo pacman -Sy --noconfirm 2>/dev/null; then
        log_info "Package database refreshed successfully" "pacman"
        fix_applied=true
    else
        log_warn "Database refresh failed" "pacman"
    fi

    # Step 2: Check for and remove orphaned dependencies
    echo -e "${BLUE}  2/4 Checking for orphaned dependencies...${NC}"
    local orphans=""
    if orphans=$(pacman -Qtdq 2>/dev/null) && [ -n "$orphans" ]; then
        echo -e "${YELLOW}    Found orphaned packages, removing...${NC}"
        if sudo pacman -Rns $orphans --noconfirm 2>/dev/null; then
            log_info "Orphaned dependencies removed" "pacman"
            fix_applied=true
        else
            log_warn "Failed to remove some orphaned dependencies" "pacman"
        fi
    else
        echo -e "${GREEN}    No orphaned dependencies found${NC}"
    fi

    # Step 3: Clear package cache and re-sync
    echo -e "${BLUE}  3/4 Clearing package cache...${NC}"
    sudo rm -f /var/cache/pacman/pkg/*.part 2>/dev/null
    sudo pacman -Syy --noconfirm 2>/dev/null

    # Step 4: Check for packages requiring updates
    echo -e "${BLUE}  4/4 Checking for AUR package conflicts...${NC}"
    if command -v pacman >/dev/null 2>&1; then
        local foreign_pkgs=$(pacman -Qm 2>/dev/null | wc -l)
        if [ "$foreign_pkgs" -gt 0 ]; then
            echo -e "${YELLOW}    Found $foreign_pkgs AUR/foreign packages${NC}"
            echo -e "${DIM}    Tip: AUR packages may cause dependency conflicts${NC}"
        fi
    fi

    if [ "$fix_applied" = true ]; then
        echo -e "${GREEN}${ICON_CHECK} Automatic fixes applied, retrying update...${NC}"
        return 0
    else
        echo -e "${YELLOW}${ICON_WARN} Could not apply automatic fixes${NC}"
        return 1
    fi
}

attempt_broken_dependency_fix() {
    echo -e "\n${CYAN}${ICON_CONFIG} Attempting to fix broken AUR dependencies...${NC}"
    log_info "Running broken dependency troubleshooting" "pacman"

    # Extract the problematic AUR package(s) from the error log
    local broken_pkgs=$(grep -i "breaks dependency.*required by" /tmp/pacman_stderr.log | sed -n "s/.*required by \(.*\)/\1/p" | sort -u)

    if [ -z "$broken_pkgs" ]; then
        echo -e "${YELLOW}Could not identify problematic packages${NC}"
        return 1
    fi

    echo -e "${YELLOW}Found problematic AUR package(s):${NC}"
    echo "$broken_pkgs" | while read pkg; do
        echo -e "  • ${CYAN}$pkg${NC}"
    done
    echo ""

    echo -e "${BLUE}Attempting to remove problematic packages temporarily...${NC}"
    local removed_pkgs=""
    local failed=false

    while IFS= read -r pkg; do
        if [ -n "$pkg" ]; then
            echo -e "  Removing ${CYAN}$pkg${NC}..."
            if sudo pacman -R "$pkg" --noconfirm 2>/dev/null; then
                log_info "Temporarily removed $pkg" "pacman"
                removed_pkgs="$removed_pkgs $pkg"
            else
                log_warn "Failed to remove $pkg" "pacman"
                failed=true
            fi
        fi
    done <<<"$broken_pkgs"

    if [ "$failed" = true ]; then
        echo -e "${YELLOW}${ICON_WARN} Could not remove all problematic packages${NC}"
        return 1
    fi

    if [ -n "$removed_pkgs" ]; then
        echo -e "${GREEN}${ICON_CHECK} Removed problematic packages, retrying update...${NC}"
        echo -e "${DIM}Note: You can reinstall these after the update with:${NC}"
        for pkg in $removed_pkgs; do
            echo -e "  ${CYAN}yay -S $pkg${NC}"
        done
        echo ""

        # Save the list for later
        echo "$removed_pkgs" >/tmp/update-script-removed-pkgs.txt

        return 0
    else
        return 1
    fi
}

attempt_git_package_conflict_fix() {
    echo -e "\n${CYAN}${ICON_CONFIG} Attempting to fix Git package conflicts...${NC}"
    log_info "Running Git package conflict resolution" "pacman"

    local DEBUG_LOG="/home/duckyonquack999/GitHub-Repositories/.cursor/debug.log"

    # Extract conflicting regular packages from error log
    # Pattern: "removing 'package-version' from target list because it conflicts with 'package-git-version'"
    local conflicting_pkgs=$(grep -i "removing '.*' from target list because it conflicts with '.*-git" /tmp/pacman_stderr.log |
        sed -n "s/.*removing '\([^']*\)' from target list.*/\1/p" | sort -u)

    #region agent log
    printf '{"sessionId":"debug-session","runId":"pre-fix","hypothesisId":"H2","location":"update-all.sh:815","message":"conflicting_pkgs_extracted","data":{"count":%d,"packages":"%s"},"timestamp":%s}\n' \
        $(echo "$conflicting_pkgs" | grep -c . 2>/dev/null || echo 0) "$(echo "$conflicting_pkgs" | tr '\n' ' ')" "$(date +%s%3N)" >>"$DEBUG_LOG" 2>/dev/null
    #endregion

    if [ -z "$conflicting_pkgs" ]; then
        echo -e "${YELLOW}Could not identify conflicting packages${NC}"
        return 1
    fi

    # Extract base package names (remove version info)
    local base_pkgs=""
    while IFS= read -r pkg; do
        if [ -n "$pkg" ]; then
            # Extract base name (everything before the last dash followed by version pattern)
            local base_name=$(echo "$pkg" | sed -E 's/-[0-9].*$//')
            base_pkgs="$base_pkgs $base_name"
        fi
    done <<<"$conflicting_pkgs"

    # Check which -git versions are actually installed
    local git_pkgs_installed=""
    local regular_pkgs_to_remove=""

    for base_pkg in $base_pkgs; do
        base_pkg=$(echo "$base_pkg" | xargs) # trim whitespace
        if [ -z "$base_pkg" ]; then
            continue
        fi

        # Check if -git version is installed
        if pacman -Q "${base_pkg}-git" &>/dev/null; then
            #region agent log
            printf '{"sessionId":"debug-session","runId":"pre-fix","hypothesisId":"H1","location":"update-all.sh:844","message":"git_package_detected","data":{"base":"%s"},"timestamp":%s}\n' \
                "$base_pkg" "$(date +%s%3N)" >>"$DEBUG_LOG" 2>/dev/null
            #endregion
            git_pkgs_installed="$git_pkgs_installed ${base_pkg}-git"
            # Find the exact regular package name that conflicts
            local regular_pkg=$(echo "$conflicting_pkgs" | grep "^${base_pkg}-" | head -1)
            if [ -n "$regular_pkg" ]; then
                regular_pkgs_to_remove="$regular_pkgs_to_remove $regular_pkg"
            fi
        else
            #region agent log
            printf '{"sessionId":"debug-session","runId":"pre-fix","hypothesisId":"H1","location":"update-all.sh:851","message":"git_package_missing","data":{"base":"%s"},"timestamp":%s}\n' \
                "$base_pkg" "$(date +%s%3N)" >>"$DEBUG_LOG" 2>/dev/null
            #endregion
        fi
    done

    #region agent log
    printf '{"sessionId":"debug-session","runId":"pre-fix","hypothesisId":"H3","location":"update-all.sh:854","message":"regular_pkgs_to_remove","data":{"packages":"%s"},"timestamp":%s}\n' \
        "$(echo "$regular_pkgs_to_remove" | tr '\n' ' ')" "$(date +%s%3N)" >>"$DEBUG_LOG" 2>/dev/null
    #endregion

    if [ -z "$regular_pkgs_to_remove" ]; then
        echo -e "${YELLOW}No conflicting regular packages found to remove${NC}"
        return 1
    fi

    echo -e "${YELLOW}Found Git package conflicts:${NC}"
    for pkg in $regular_pkgs_to_remove; do
        pkg=$(echo "$pkg" | xargs)
        local base_name=$(echo "$pkg" | sed -E 's/-[0-9].*$//')
        local git_version=$(pacman -Q "${base_name}-git" 2>/dev/null | awk '{print $2}')
        echo -e "  • ${CYAN}$pkg${NC} conflicts with ${GREEN}${base_name}-git-${git_version}${NC}"
    done
    echo ""

    echo -e "${BLUE}Removing conflicting regular packages (keeping -git versions)...${NC}"
    local removed_pkgs=""
    local failed=false

    for pkg in $regular_pkgs_to_remove; do
        pkg=$(echo "$pkg" | xargs)
        if [ -n "$pkg" ]; then
            # Extract base name for removal
            local base_name=$(echo "$pkg" | sed -E 's/-[0-9].*$//')
            if pacman -Q "$base_name" &>/dev/null; then
                #region agent log
                printf '{"sessionId":"debug-session","runId":"pre-fix","hypothesisId":"H2","location":"update-all.sh:892","message":"regular_pkg_installed","data":{"base":"%s"},"timestamp":%s}\n' \
                    "$base_name" "$(date +%s%3N)" >>"$DEBUG_LOG" 2>/dev/null
                #endregion
            else
                #region agent log
                printf '{"sessionId":"debug-session","runId":"pre-fix","hypothesisId":"H2","location":"update-all.sh:896","message":"regular_pkg_not_installed","data":{"base":"%s"},"timestamp":%s}\n' \
                    "$base_name" "$(date +%s%3N)" >>"$DEBUG_LOG" 2>/dev/null
                #endregion
            fi
            echo -e "  Removing ${CYAN}$base_name${NC}..."
            if sudo pacman -R "$base_name" --noconfirm 2>/dev/null; then
                log_info "Removed conflicting regular package: $base_name" "pacman"
                removed_pkgs="$removed_pkgs $base_name"
            else
                #region agent log
                printf '{"sessionId":"debug-session","runId":"pre-fix","hypothesisId":"H3","location":"update-all.sh:877","message":"removal_failed","data":{"base":"%s"},"timestamp":%s}\n' \
                    "$base_name" "$(date +%s%3N)" >>"$DEBUG_LOG" 2>/dev/null
                #endregion
                log_warn "Failed to remove $base_name" "pacman"
                failed=true
            fi
        fi
    done

    if [ "$failed" = true ]; then
        echo -e "${YELLOW}${ICON_WARN} Could not remove all conflicting packages${NC}"
        return 1
    fi

    if [ -n "$removed_pkgs" ]; then
        echo -e "${GREEN}${ICON_CHECK} Removed conflicting regular packages, keeping -git versions${NC}"
        echo -e "${DIM}Note: -git versions are typically more up-to-date and will be kept${NC}"
        echo ""

        # Append to removed packages list (merge with existing if any)
        if [ -f /tmp/update-script-removed-pkgs.txt ]; then
            echo "$removed_pkgs" >>/tmp/update-script-removed-pkgs.txt
        else
            echo "$removed_pkgs" >/tmp/update-script-removed-pkgs.txt
        fi

        return 0
    else
        return 1
    fi
}

prompt_manual_intervention() {
    local issue_type="${1:-problem}"
    local error_log="${2:-}"
    local auto_fix="${3:-true}"

    # Skip prompt in non-interactive mode
    if [ "$NONINTERACTIVE" -eq 1 ]; then
        log_warn "Non-interactive mode: skipping manual intervention prompt" "system"
        return 1
    fi

    echo -e "\n${YELLOW}${ICON_WARN} Manual intervention required${NC}"
    echo -e "${BOLD}What would you like to do?${NC}"
    echo -e "  ${GREEN}1)${NC} Try automatic fixes and retry"
    echo -e "  ${CYAN}2)${NC} Open shell for manual fixing and retry"
    echo -e "  ${YELLOW}3)${NC} Skip this step and continue"
    echo -e "  ${RED}4)${NC} Abort the update process"
    echo ""

    local choice=""
    while true; do
        read -p "Enter your choice (1-4): " choice
        case "$choice" in
        1)
            # Attempt automatic fixes based on issue type
            if [ "$issue_type" = "git package conflict" ] && [ "$auto_fix" = "true" ]; then
                if attempt_git_package_conflict_fix; then
                    return 0 # Retry after automatic fix
                else
                    echo -e "\n${YELLOW}Automatic fixes unsuccessful.${NC}"
                    echo -e "Choose option 2 to fix manually, or 3 to skip.\n"
                    continue
                fi
            elif [ "$issue_type" = "dependency issue" ] && [ "$auto_fix" = "true" ]; then
                if attempt_dependency_fix; then
                    return 0 # Retry after automatic fix
                else
                    echo -e "\n${YELLOW}Automatic fixes unsuccessful.${NC}"
                    echo -e "Choose option 2 to fix manually, or 3 to skip.\n"
                    continue
                fi
            elif [ "$issue_type" = "broken dependency" ] && [ "$auto_fix" = "true" ]; then
                if attempt_broken_dependency_fix; then
                    return 0 # Retry after automatic fix
                else
                    echo -e "\n${YELLOW}Automatic fixes unsuccessful.${NC}"
                    echo -e "Choose option 2 to fix manually, or 3 to skip.\n"
                    continue
                fi
            else
                echo -e "${YELLOW}No automatic fixes available for $issue_type${NC}"
                echo -e "Please use option 2 for manual intervention.\n"
                continue
            fi
            ;;
        2)
            echo -e "\n${CYAN}Opening a shell for manual intervention...${NC}"
            echo -e "${DIM}Fix the issue, then type 'exit' to return to the script${NC}"
            echo -e "${DIM}Example: sudo pacman -Syu${NC}\n"

            # Open interactive shell
            bash -i

            echo -e "\n${CYAN}Returning to update script...${NC}"
            return 0 # Retry
            ;;
        3)
            log_info "User chose to skip this step" "system"
            return 1 # Skip
            ;;
        4)
            log_info "User chose to abort" "system"
            echo -e "\n${RED}Aborting update process...${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1, 2, 3, or 4.${NC}"
            ;;
        esac
    done
}

check_network() {
    echo -e "\n${CYAN}${ICON_NETWORK} Checking network connectivity...${NC}"
    local timeout=5
    if ! ping -c 1 -W $timeout 8.8.8.8 &>/dev/null && ! ping -c 1 -W $timeout 1.1.1.1 &>/dev/null; then
        handle_error_with_rollback "No internet connection detected" "NETWORK_ERROR" "network"
        return 1
    fi
    if ! getent hosts archlinux.org >/dev/null 2>&1; then
        log_warn "DNS resolution failed for archlinux.org" "network"
        if [ "$DNS_FALLBACK" = "1" ]; then
            echo -e "${YELLOW}Applying temporary DNS fallback (1.1.1.1)...${NC}"
            if command -v resolvconf >/dev/null 2>&1; then
                sudo resolvconf -a tmp-dns <<<"nameserver 1.1.1.1" 2>/dev/null || true
            elif systemctl is-active systemd-resolved >/dev/null 2>&1; then
                sudo bash -c 'printf "nameserver 1.1.1.1\n" > /run/systemd/resolve/resolv.conf' 2>/dev/null || true
            fi
        fi
    fi
    echo -e "${GREEN}${ICON_CHECK} Network connection established${NC}"
    return 0
}

detect_environment() {
    echo -e "\n${CYAN}${ICON_SYSTEM} Detecting system environment...${NC}"

    if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        log_message "INFO" "Wayland session detected"
        echo -e "${GREEN}${ICON_CHECK} Wayland session detected${NC}"

        if pgrep -x "Hyprland" >/dev/null; then
            log_message "INFO" "Hyprland compositor detected"
            echo -e "${GREEN}${ICON_CHECK} Hyprland compositor detected${NC}"
        fi
    else
        log_message "INFO" "X11 session detected"
        echo -e "${GREEN}${ICON_CHECK} X11 session detected${NC}"
    fi

    if pgrep -x "plasmashell" >/dev/null; then
        log_message "INFO" "KDE Plasma detected"
        echo -e "${GREEN}${ICON_CHECK} KDE Plasma detected${NC}"
    fi
}

# FIXED: Safe progress display with default values
show_progress() {
    local current=${1:-0}
    local total=${2:-1}

    # Ensure variables are properly set and numeric
    current=${current//[^0-9]/}
    total=${total//[^0-9]/}
    current=${current:-0}
    total=${total:-1}

    # Prevent division by zero
    [ "$total" -eq 0 ] && total=1
    [ "$current" -lt 0 ] && current=0

    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    printf "\r${BLUE}["
    printf "%${filled}s" | tr ' ' '▓'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${NC} %3d%%" $percentage
}

# FIXED: Backup configs function with proper variable scoping
backup_configs() {
    echo -e "\n${BLUE}${ICON_BACKUP} Backing up system configurations...${NC}"
    mkdir -p "$BACKUP_DIR"

    local sudo_ok=0
    for attempt in {1..3}; do
        if timeout 5 sudo -v 2>/dev/null; then
            sudo_ok=1
            log_debug "Sudo cache active (attempt $attempt)"
            break
        fi
        sleep 1
    done
    if [ "$sudo_ok" -eq 0 ]; then
        log_warn "Sudo access failed after retries; skipping all config backups"
        echo -e "${YELLOW}${ICON_WARN} Skipping backups due to sudo issues${NC}"
        return 0
    fi

    # FIX: Calculate total inside the same scope where it's used
    local total=${#IMPORTANT_CONFIGS[@]}
    local current=0

    # FIX: Use a function instead of subshell to maintain variable scope
    backup_configs_internal() {
        for config in "${IMPORTANT_CONFIGS[@]}"; do
            ((current++))
            if [ -e "$config" ]; then
                show_progress "$current" "$total"
                local cp_cmd="cp -r \"$config\" \"$BACKUP_DIR/\""
                local stderr_log="/tmp/backup_cp_stderr_$$.log"
                if [[ "$config" == /etc/* ]]; then
                    cp_cmd="sudo $cp_cmd"
                fi
                if eval "$cp_cmd 2> >(tee \"$stderr_log\" >&2)"; then
                    log_message "INFO" "Backed up: $config"
                    rm -f "$stderr_log"
                else
                    local cp_error=$(cat "$stderr_log" 2>/dev/null || echo "Unknown cp error")
                    log_message "ERROR" "Failed to back up: $config (details: $cp_error)"
                    rm -f "$stderr_log"
                    ((FAILED_OPERATIONS++))
                fi
            fi
        done
    }

    # Call the internal function
    backup_configs_internal || log_warn "Backup loop encountered issues (continuing)"

    if ! sudo chown -R "$USER:$USER" "$BACKUP_DIR" 2>/dev/null; then
        log_warn "Ownership restoration for backups failed (non-critical)"
    fi
    echo -e "\n${GREEN}${ICON_CHECK} Backups completed: $BACKUP_DIR${NC}"
}

recover_pacman_sync() {
    echo -e "${YELLOW}Attempting automated recovery for pacman sync errors...${NC}"
    log_warn "Starting pacman sync recovery" "pacman"

    sudo rm -f /var/lib/pacman/db.lck 2>/dev/null
    sudo pacman -Syy || true

    case "$DISTRO_BASE" in
    manjaro)
        if ! pacman -Q manjaro-keyring &>/dev/null; then
            sudo pacman -S --needed --noconfirm manjaro-keyring || true
        fi
        ;;
    *)
        if ! pacman -Q archlinux-keyring &>/dev/null; then
            sudo pacman -S --needed --noconfirm archlinux-keyring || true
        fi
        ;;
    esac
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux manjaro 2>/dev/null || true
    sudo pacman-key --refresh-keys 2>/dev/null || true

    sudo rm -f /var/lib/pacman/sync/*.part 2>/dev/null || true

    if [ "$DISTRO_BASE" = "manjaro" ] && command -v pacman-mirrors >/dev/null 2>&1; then
        echo -e "${BLUE}${ICON_NETWORK} Refreshing Manjaro mirrors...${NC}"
        if [ -n "$MIRROR_COUNTRY" ]; then
            sudo pacman-mirrors --country ${MIRROR_COUNTRY//,/ } 2>/dev/null || true
        else
            sudo pacman-mirrors --fasttrack 5 2>/dev/null || true
        fi
    elif command -v reflector >/dev/null 2>&1; then
        echo -e "${BLUE}${ICON_NETWORK} Refreshing Arch mirrors with reflector...${NC}"
        if [ -n "$MIRROR_COUNTRY" ]; then
            sudo reflector --country "$MIRROR_COUNTRY" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true
        else
            sudo reflector --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true
        fi
    fi

    sudo pacman -Syy || true

    for db in /var/lib/pacman/sync/*.db; do
        [ -f "$db" ] || continue
        if ! bsdtar -tf "$db" >/dev/null 2>&1; then
            sudo rm -f "$db" 2>/dev/null || true
        fi
    done
}

pacman_update_with_recovery() {
    if [ -f /var/lib/pacman/db.lck ]; then
        log_warn "Stale pacman lock detected; removing to prevent hang" "pacman"
        sudo rm -f /var/lib/pacman/db.lck
    fi

    # Choose upgrade command based on downgrade flag
    local upgrade_flag="Syu"
    [ "$ALLOW_DOWNGRADE" -eq 1 ] && upgrade_flag="Syud"

    local base_cmd="sudo pacman -${upgrade_flag} --noconfirm"
    [ "$DRY_RUN" = "1" ] && base_cmd="echo DRY-RUN: pacman -${upgrade_flag}"
    local timed_cmd="timeout 300 $base_cmd"

    # Retry loop for manual intervention
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if eval "$timed_cmd" 2> >(tee /tmp/pacman_stderr.log >&2); then
            return 0
        fi

        # Check for "breaks dependency" FIRST - these are AUR package issues
        if grep -qi "breaks dependency" /tmp/pacman_stderr.log; then
            log_error "AUR package dependency break detected - manual intervention required" "pacman"
            echo -e "${RED}${ICON_ERROR} Broken Dependency Detected${NC}"
            echo ""
            show_error_context "/tmp/pacman_stderr.log" 10
            echo ""

            # Try to extract the problematic package
            local broken_pkg=$(grep -i "breaks dependency.*required by" /tmp/pacman_stderr.log | sed -n "s/.*required by \(.*\)/\1/p" | head -1)

            if [ -n "$broken_pkg" ]; then
                echo -e "${YELLOW}Problematic AUR package: ${CYAN}$broken_pkg${NC}"
                echo ""
            fi

            echo -e "${YELLOW}Common resolutions:${NC}"
            if [ -n "$broken_pkg" ]; then
                echo -e "  ${GREEN}Recommended:${NC} Remove and reinstall after update"
                echo -e "    ${CYAN}sudo pacman -R $broken_pkg${NC}"
                echo -e "    ${CYAN}sudo pacman -Syu${NC}"
                echo -e "    ${CYAN}yay -S $broken_pkg${NC}  # or paru"
                echo ""
            fi
            echo -e "  • Rebuild AUR package: ${CYAN}yay -S <package> --rebuild${NC}"
            echo -e "  • Skip update temporarily: ${CYAN}sudo pacman -Syu --ignore <package>${NC}"
            echo -e "  • List all AUR packages: ${CYAN}pacman -Qm${NC}"
            echo ""

            # Prompt for manual intervention
            if prompt_manual_intervention "broken dependency" "/tmp/pacman_stderr.log"; then
                ((retry_count++))
                log_info "Retrying pacman update (attempt $((retry_count + 1))/$max_retries)..." "pacman"
                continue
            else
                log_warn "User chose to skip package update" "pacman"
                return 1
            fi
        fi

        # Check for Git package conflicts - these can be automatically resolved
        if grep -qi "removing '.*' from target list because it conflicts with '.*-git" /tmp/pacman_stderr.log; then
            log_error "Git package conflicts detected" "pacman"
            echo -e "${RED}${ICON_ERROR} Git Package Conflict Detected${NC}"
            echo ""
            show_error_context "/tmp/pacman_stderr.log" 15
            echo ""

            # Extract and display conflicting packages
            local conflicting_pkgs=$(grep -i "removing '.*' from target list because it conflicts with '.*-git" /tmp/pacman_stderr.log |
                sed -n "s/.*removing '\([^']*\)' from target list because it conflicts with '\([^']*\)'.*/\1 conflicts with \2/p" | sort -u)

            if [ -n "$conflicting_pkgs" ]; then
                echo -e "${YELLOW}The following regular packages conflict with installed -git versions:${NC}"
                echo "$conflicting_pkgs" | while read conflict_line; do
                    local regular_pkg=$(echo "$conflict_line" | sed -n "s/\(.*\) conflicts with .*/\1/p")
                    local git_pkg=$(echo "$conflict_line" | sed -n "s/.* conflicts with \(.*\)/\1/p")
                    echo -e "  • ${CYAN}$regular_pkg${NC} conflicts with ${GREEN}$git_pkg${NC}"
                done
                echo ""
                echo -e "${GREEN}Recommendation:${NC} Keep -git versions (they're typically more up-to-date)"
                echo -e "${DIM}The script will automatically remove the conflicting regular packages.${NC}"
                echo ""
            fi

            # Try automatic fix
            if [ "$NONINTERACTIVE" -eq 1 ]; then
                # Non-interactive mode: try automatic fix
                if attempt_git_package_conflict_fix; then
                    ((retry_count++))
                    log_info "Retrying pacman update after Git conflict resolution (attempt $((retry_count + 1))/$max_retries)..." "pacman"
                    continue
                else
                    log_error "Automatic Git conflict resolution failed" "pacman"
                    return 1
                fi
            else
                # Interactive mode: prompt user
                echo -e "${YELLOW}Common resolutions:${NC}"
                echo -e "  ${GREEN}Recommended:${NC} Remove conflicting regular packages (keeping -git versions)"
                echo -e "    ${CYAN}sudo pacman -R <regular-package>${NC}"
                echo -e "  • Review details: ${CYAN}sudo pacman -Syu${NC}"
                echo ""

                # Prompt for manual intervention
                if prompt_manual_intervention "git package conflict" "/tmp/pacman_stderr.log"; then
                    ((retry_count++))
                    log_info "Retrying pacman update (attempt $((retry_count + 1))/$max_retries)..." "pacman"
                    continue
                else
                    log_warn "User chose to skip package update" "pacman"
                    return 1
                fi
            fi
        fi

        # Check for package conflicts - these require manual intervention
        if grep -qi "conflicting dependencies\|package conflicts\|unresolvable package conflicts" /tmp/pacman_stderr.log; then
            log_error "Package conflicts detected - manual intervention required" "pacman"
            echo -e "${RED}${ICON_ERROR} Package Conflict Detected${NC}"
            echo ""
            show_error_context "/tmp/pacman_stderr.log" 10
            echo ""
            echo -e "${YELLOW}Common resolutions:${NC}"
            echo -e "  • Remove conflicting package: ${CYAN}sudo pacman -R <package>${NC}"
            echo -e "  • Review details: ${CYAN}sudo pacman -Syu${NC}"
            echo ""

            # Prompt for manual intervention
            if prompt_manual_intervention "package conflict" "/tmp/pacman_stderr.log"; then
                ((retry_count++))
                log_info "Retrying pacman update (attempt $((retry_count + 1))/$max_retries)..." "pacman"
                continue
            else
                log_warn "User chose to skip package update" "pacman"
                return 1
            fi
        fi

        # Check for generic dependency issues
        if grep -qi "could not satisfy dependencies\|failed to prepare transaction" /tmp/pacman_stderr.log; then
            log_error "Dependency issues detected - manual intervention required" "pacman"
            echo -e "${RED}${ICON_ERROR} Dependency Problem Detected${NC}"
            echo ""
            show_error_context "/tmp/pacman_stderr.log" 10
            echo ""
            echo -e "${YELLOW}Common resolutions:${NC}"
            echo -e "  • Update package database: ${CYAN}sudo pacman -Sy${NC}"
            echo -e "  • Check for broken packages: ${CYAN}sudo pacman -Qk${NC}"
            echo -e "  • Skip problematic package: ${CYAN}sudo pacman -Syu --ignore <package>${NC}"
            echo -e "  • Review AUR packages: ${CYAN}pacman -Qm${NC}"
            echo ""

            # Prompt for manual intervention
            if prompt_manual_intervention "dependency issue" "/tmp/pacman_stderr.log"; then
                ((retry_count++))
                log_info "Retrying pacman update (attempt $((retry_count + 1))/$max_retries)..." "pacman"
                continue
            else
                log_warn "User chose to skip package update" "pacman"
                return 1
            fi
        fi

        # If not a conflict, break out of retry loop
        break
    done

    # Handle other error types (outside retry loop)
    if [ $retry_count -ge $max_retries ]; then
        log_error "Maximum retry attempts reached for package conflicts" "pacman"
        return 1
    fi

    if grep -qi "failed to synchronize all databases" /tmp/pacman_stderr.log; then
        log_error "Pacman sync failed; attempting recovery" "pacman"
        recover_pacman_sync
        if eval "$timed_cmd"; then
            return 0
        fi
    fi

    if grep -qi "PGP signature" /tmp/pacman_stderr.log; then
        log_warn "PGP signature issue detected; refreshing keyrings and clearing cached signatures" "pacman"
        case "$DISTRO_BASE" in
        manjaro)
            sudo pacman -S --noconfirm --needed manjaro-keyring || true
            ;;
        *)
            sudo pacman -S --noconfirm --needed archlinux-keyring || true
            ;;
        esac
        sudo rm -f /var/cache/pacman/pkg/*.sig 2>/dev/null || true
        sudo pacman-key --refresh-keys 2>/dev/null || true
        if eval "$timed_cmd"; then
            return 0
        fi
    fi
    return 1
}

# =============================================================================
# TOPGRADE-INSPIRED UPDATE FUNCTIONS
# =============================================================================

update_firmware() {
    if [ "$SKIP_FIRMWARE" -eq 1 ]; then
        log_info "Skipping firmware updates" "firmware"
        return 0
    fi

    if ! check_command fwupdmgr; then
        log_warn "fwupdmgr not found" "firmware"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_FIRMWARE} Updating firmware...${NC}"
    log_info "Updating firmware with fwupdmgr" "firmware"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "firmware"

    local cmd="sudo fwupdmgr get-updates && sudo fwupdmgr update"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Firmware update failed" "FIRMWARE_ERROR" "firmware"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Firmware updated successfully${NC}"
    return 0
}

update_git_repos() {
    if [ "$SKIP_GIT" -eq 1 ]; then
        log_info "Skipping Git repository updates" "git"
        return 0
    fi

    if ! check_command git; then
        log_warn "git not found" "git"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_GIT} Updating Git repositories...${NC}"
    log_info "Pulling Git repositories" "git"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "git"

    local updated_count=0
    for repo in "${GIT_REPOS[@]}"; do
        if [ -d "$repo/.git" ]; then
            local cmd="git -C \"$repo\" pull"
            [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"
            if eval "$cmd"; then
                ((updated_count++))
            else
                log_warn "Failed to pull $repo" "git"
            fi
        fi
    done

    TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + updated_count))
    v_echo "${GREEN}${ICON_CHECK} $updated_count Git repositories updated${NC}"
    return 0
}

update_cargo() {
    if [ "$SKIP_CARGO" -eq 1 ]; then
        log_info "Skipping Cargo updates" "cargo"
        return 0
    fi

    if ! check_command cargo; then
        log_warn "cargo not found" "cargo"
        return 0
    fi

    if check_command cargo-install-update; then
        local cmd="cargo install-update -a"
    else
        log_warn "cargo-install-update not installed; skipping detailed Cargo update" "cargo"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Cargo packages...${NC}"
    log_info "Updating Cargo with $cmd" "cargo"

    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Cargo update failed" "CARGO_ERROR" "cargo"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Cargo packages updated successfully${NC}"
    return 0
}

update_pip() {
    if [ "$SKIP_PIP" -eq 1 ]; then
        log_info "Skipping Pip updates" "pip"
        return 0
    fi

    if ! check_command pip3; then
        log_warn "pip3 not found" "pip"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Pip packages...${NC}"
    log_info "Updating Pip user packages" "pip"

    local cmd="pip3 list --user --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! eval "$cmd"; then
        handle_error_with_rollback "Pip update failed" "PIP_ERROR" "pip"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Pip packages updated successfully${NC}"
    return 0
}

update_npm() {
    if [ "$SKIP_NPM" -eq 1 ]; then
        log_info "Skipping Npm updates" "npm"
        return 0
    fi

    if ! check_command npm; then
        log_warn "npm not found" "npm"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Npm global packages...${NC}"
    log_info "Updating Npm globals" "npm"

    local cmd="npm update -g"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Npm update failed" "NPM_ERROR" "npm"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Npm packages updated successfully${NC}"
    return 0
}

update_gem() {
    if [ "$SKIP_GEM" -eq 1 ]; then
        log_info "Skipping Gem updates" "gem"
        return 0
    fi

    if ! check_command gem; then
        log_warn "gem not found" "gem"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Ruby Gems...${NC}"
    log_info "Updating Gems" "gem"

    local cmd="gem update"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Gem update failed" "GEM_ERROR" "gem"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Gems updated successfully${NC}"
    return 0
}

update_composer() {
    if [ "$SKIP_COMPOSER" -eq 1 ]; then
        log_info "Skipping Composer updates" "composer"
        return 0
    fi

    if ! check_command composer; then
        log_warn "composer not found" "composer"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Composer globals...${NC}"
    log_info "Updating Composer" "composer"

    local cmd="composer global update"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Composer update failed" "COMPOSER_ERROR" "composer"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Composer updated successfully${NC}"
    return 0
}

update_shell_configs() {
    if [ "$SKIP_SHELL" -eq 1 ]; then
        log_info "Skipping shell configuration updates" "shell"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_CONFIG} Updating shell configurations...${NC}"
    log_info "Updating shell configs" "shell"

    for shell_update in "${SHELL_UPDATES[@]}"; do
        case "$shell_update" in
        "oh-my-zsh")
            if [ -d "$HOME/.oh-my-zsh" ]; then
                local cmd="sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/upgrade.sh)\""
                [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"
                eval "$cmd" || log_warn "Failed to update oh-my-zsh" "shell"
            fi
            ;;
        # Add more shell updates like fisher: fish -c "fisher update"
        esac
    done

    v_echo "${GREEN}${ICON_CHECK} Shell configurations updated${NC}"
    return 0
}

update_vscode_extensions() {
    if [ "$SKIP_VSCODE" -eq 1 ]; then
        log_info "Skipping VS Code extension updates" "vscode"
        return 0
    fi

    if ! check_command code; then
        log_warn "code not found" "vscode"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating VS Code extensions...${NC}"
    log_info "Updating VS Code extensions" "vscode"

    local cmd="code --list-extensions | xargs -L 1 code --install-extension"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! eval "$cmd"; then
        handle_error_with_rollback "VS Code extensions update failed" "VSCODE_ERROR" "vscode"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} VS Code extensions updated successfully${NC}"
    return 0
}

update_custom_commands() {
    if [ "$SKIP_CUSTOM" -eq 1 ]; then
        log_info "Skipping custom commands" "custom"
        return 0
    fi

    if [ ${#CUSTOM_COMMANDS[@]} -eq 0 ]; then
        log_info "No custom commands defined" "custom"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_CONFIG} Running custom commands...${NC}"
    log_info "Executing custom commands" "custom"

    for cmd in "${CUSTOM_COMMANDS[@]}"; do
        [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"
        if ! eval "$cmd"; then
            log_warn "Custom command failed: $cmd" "custom"
        fi
    done

    v_echo "${GREEN}${ICON_CHECK} Custom commands executed${NC}"
    return 0
}

# NEW: Additional Topgrade-inspired functions

update_homebrew() {
    if [ "$SKIP_HOMEBREW" -eq 1 ]; then
        log_info "Skipping Homebrew updates" "homebrew"
        return 0
    fi

    if ! check_command brew; then
        log_warn "brew not found (install Linuxbrew if needed)" "homebrew"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Homebrew packages...${NC}"
    log_info "Updating Homebrew" "homebrew"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "homebrew"

    local cmd="brew update && brew upgrade"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Homebrew update failed" "HOMEBREW_ERROR" "homebrew"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Homebrew packages updated successfully${NC}"
    return 0
}

update_go() {
    if [ "$SKIP_GO" -eq 1 ]; then
        log_info "Skipping Go updates" "go"
        return 0
    fi

    if ! check_command go; then
        log_warn "go not found" "go"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Go modules...${NC}"
    log_info "Updating Go modules" "go"

    local cmd="go list -m all | go get -u"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Go update failed" "GO_ERROR" "go"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Go modules updated successfully${NC}"
    return 0
}

update_haskell() {
    if [ "$SKIP_HASKELL" -eq 1 ]; then
        log_info "Skipping Haskell updates" "haskell"
        return 0
    fi

    local haskell_tool=""
    if check_command stack; then
        haskell_tool="stack"
    elif check_command ghcup; then
        haskell_tool="ghcup"
    else
        log_warn "No Haskell tool found (stack or ghcup)" "haskell"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Haskell packages...${NC}"
    log_info "Updating Haskell with $haskell_tool" "haskell"

    local cmd=""
    if [ "$haskell_tool" = "stack" ]; then
        cmd="stack upgrade"
    else
        cmd="ghcup upgrade"
    fi
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Haskell update failed" "HASKELL_ERROR" "haskell"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Haskell packages updated successfully${NC}"
    return 0
}

update_lua() {
    if [ "$SKIP_LUA" -eq 1 ]; then
        log_info "Skipping Lua updates" "lua"
        return 0
    fi

    if ! check_command luarocks; then
        log_warn "luarocks not found" "lua"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Lua rocks...${NC}"
    log_info "Updating Lua with luarocks" "lua"

    local cmd="luarocks update"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Lua update failed" "LUA_ERROR" "lua"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Lua rocks updated successfully${NC}"
    return 0
}

update_docker() {
    if [ "$SKIP_DOCKER" -eq 1 ]; then
        log_info "Skipping Docker/Podman updates" "docker"
        return 0
    fi

    local container_tool=""
    if check_command podman; then
        container_tool="podman" # Prefer Podman on Arch for rootless
    elif check_command docker; then
        container_tool="docker"
    else
        log_warn "No container tool found (podman or docker)" "docker"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_PACKAGE} Updating $container_tool images...${NC}"
    log_info "Updating $container_tool images" "docker"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "docker"

    local cmd="$container_tool images -q | sort -u | xargs -r $container_tool pull"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Container update failed" "DOCKER_ERROR" "docker"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} $container_tool images updated successfully${NC}"
    return 0
}

update_neovim() {
    if [ "$SKIP_NEOVIM" -eq 1 ]; then
        log_info "Skipping Neovim plugin updates" "neovim"
        return 0
    fi

    if ! check_command nvim; then
        log_warn "nvim not found" "neovim"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Neovim plugins...${NC}"
    log_info "Updating Neovim plugins (assuming packer.nvim)" "neovim"

    # Assume packer.nvim; adjust for other managers
    if [ -f "$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim/packer.lua" ]; then
        local cmd="nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'"
        [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"
        eval "$cmd" || log_warn "Neovim PackerSync failed" "neovim"
    else
        # Fallback: Git pull for plugin dirs
        local updated_count=0
        for plugin in "${NEOVIM_PLUGINS[@]}"; do
            if [ -d "$plugin/.git" ]; then
                local git_cmd="git -C \"$plugin\" pull"
                [ "$DRY_RUN" = "1" ] && git_cmd="echo DRY-RUN: $git_cmd"
                if eval "$git_cmd"; then
                    ((updated_count++))
                fi
            fi
        done
        TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + updated_count))
    fi

    v_echo "${GREEN}${ICON_CHECK} Neovim plugins updated${NC}"
    return 0
}

# NEW: More Topgrade-inspired functions and Guix

update_nix() {
    if [ "$SKIP_NIX" -eq 1 ]; then
        log_info "Skipping Nix/Lix updates" "nix"
        return 0
    fi

    local nix_tool=""
    if check_command lix; then
        nix_tool="lix" # Prefer Lix if available
    elif check_command nix; then
        nix_tool="nix"
    else
        log_warn "No Nix/Lix tool found" "nix"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_PACKAGE} Updating $nix_tool packages...${NC}"
    log_info "Updating $nix_tool channels and env" "nix"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "nix"

    local cmd="$nix_tool-channel --update && $nix_tool-env -u"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Nix/Lix update failed" "NIX_ERROR" "nix"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} $nix_tool packages updated successfully${NC}"
    return 0
}

update_opam() {
    if [ "$SKIP_OPAM" -eq 1 ]; then
        log_info "Skipping Opam updates" "opam"
        return 0
    fi

    if ! check_command opam; then
        log_warn "opam not found" "opam"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Opam packages...${NC}"
    log_info "Updating Opam" "opam"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "opam"

    local cmd="opam update && opam upgrade"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Opam update failed" "OPAM_ERROR" "opam"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Opam packages updated successfully${NC}"
    return 0
}

update_vcpkg() {
    if [ "$SKIP_VCPKG" -eq 1 ]; then
        log_info "Skipping Vcpkg updates" "vcpkg"
        return 0
    fi

    if ! check_command vcpkg; then
        log_warn "vcpkg not found" "vcpkg"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Vcpkg libraries...${NC}"
    log_info "Updating Vcpkg" "vcpkg"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "vcpkg"

    local cmd="vcpkg update"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Vcpkg update failed" "VCPKG_ERROR" "vcpkg"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Vcpkg libraries updated successfully${NC}"
    return 0
}

update_yarn() {
    if [ "$SKIP_YARN" -eq 1 ]; then
        log_info "Skipping Yarn updates" "yarn"
        return 0
    fi

    if ! check_command yarn; then
        log_warn "yarn not found" "yarn"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Yarn global packages...${NC}"
    log_info "Updating Yarn globals" "yarn"

    local cmd="yarn global upgrade"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Yarn update failed" "YARN_ERROR" "yarn"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Yarn packages updated successfully${NC}"
    return 0
}

update_rustup() {
    if [ "$SKIP_RUSTUP" -eq 1 ]; then
        log_info "Skipping Rustup updates" "rustup"
        return 0
    fi

    if ! check_command rustup; then
        log_warn "rustup not found" "rustup"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Rust toolchain...${NC}"
    log_info "Updating Rustup" "rustup"

    local cmd="rustup self update && rustup update"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Rustup update failed" "RUSTUP_ERROR" "rustup"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Rust toolchain updated successfully${NC}"
    return 0
}

update_tmux() {
    if [ "$SKIP_TMUX" -eq 1 ]; then
        log_info "Skipping Tmux plugin updates" "tmux"
        return 0
    fi

    if ! check_command tmux; then
        log_warn "tmux not found" "tmux"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_CONFIG} Updating Tmux plugins...${NC}"
    log_info "Updating Tmux plugins (assuming TPM)" "tmux"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "tmux"

    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        local cmd="~/.tmux/plugins/tpm/bin/install_plugins"
        [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"
        eval "$cmd" || log_warn "Tmux TPM update failed" "tmux"
    else
        # Fallback: Git pull for plugin dirs
        local updated_count=0
        for plugin in "${TMUX_PLUGINS[@]}"; do
            if [ -d "$plugin/.git" ]; then
                local git_cmd="git -C \"$plugin\" pull"
                [ "$DRY_RUN" = "1" ] && git_cmd="echo DRY-RUN: $git_cmd"
                if eval "$git_cmd"; then
                    ((updated_count++))
                fi
            fi
        done
        TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + updated_count))
    fi

    v_echo "${GREEN}${ICON_CHECK} Tmux plugins updated${NC}"
    return 0
}

update_vim() {
    if [ "$SKIP_VIM" -eq 1 ]; then
        log_info "Skipping Vim plugin updates" "vim"
        return 0
    fi

    if ! check_command vim; then
        log_warn "vim not found" "vim"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_LANG} Updating Vim plugins...${NC}"
    log_info "Updating Vim plugins (assuming vim-plug)" "vim"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "vim"

    if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
        local cmd="vim +PlugUpgrade +qa!"
        [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"
        eval "$cmd" || log_warn "Vim PlugUpgrade failed" "vim"
    else
        # Fallback: Git pull for plugin dirs
        local updated_count=0
        for plugin in "${VIM_PLUGINS[@]}"; do
            if [ -d "$plugin/.git" ]; then
                local git_cmd="git -C \"$plugin\" pull"
                [ "$DRY_RUN" = "1" ] && git_cmd="echo DRY-RUN: $git_cmd"
                if eval "$git_cmd"; then
                    ((updated_count++))
                fi
            fi
        done
        TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + updated_count))
    fi

    v_echo "${GREEN}${ICON_CHECK} Vim plugins updated${NC}"
    return 0
}

update_starship() {
    if [ "$SKIP_STARSHIP" -eq 1 ]; then
        log_info "Skipping Starship updates" "starship"
        return 0
    fi

    if ! check_command starship; then
        log_warn "starship not found" "starship"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_CONFIG} Updating Starship prompt...${NC}"
    log_info "Updating Starship" "starship"

    local cmd="curl -sS https://starship.rs/install.sh | sh -s -- -y"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Starship update failed" "STARSHIP_ERROR" "starship"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Starship updated successfully${NC}"
    return 0
}

update_guix() {
    if [ "$SKIP_GUIX" -eq 1 ]; then
        log_info "Skipping Guix updates" "guix"
        return 0
    fi

    if ! check_command guix; then
        log_warn "guix not found" "guix"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_PACKAGE} Updating Guix packages...${NC}"
    log_info "Updating Guix channels and profile" "guix"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "guix"

    local cmd="guix pull && guix package -u"
    [ "$DRY_RUN" = "1" ] && cmd="echo DRY-RUN: $cmd"

    if ! retry "$cmd" 2 3; then
        handle_error_with_rollback "Guix update failed" "GUIX_ERROR" "guix"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Guix packages updated successfully${NC}"
    return 0
}

# =============================================================================
# MAIN EXECUTION FUNCTIONS
# =============================================================================

update_system_packages() {
    log_info "Starting system package updates" "pacman"
    v_echo "\n${CYAN}${ICON_PACKAGE} Updating system packages...${NC}"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "pacman"

    snapshot_pre

    if ! pacman_update_with_recovery; then
        handle_error_with_rollback "System package update failed" "PACMAN_ERROR" "pacman"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} System packages updated successfully${NC}"
    snapshot_post

    local updated_count=$(pacman -Qu 2>/dev/null | wc -l || echo 0)
    updated_count=${updated_count//[^0-9]/}
    updated_count=${updated_count:-0}
    TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + updated_count))

    return 0
}

update_aur_packages() {
    if [ "$SKIP_AUR" -eq 1 ]; then
        log_info "Skipping AUR updates" "aur"
        return 0
    fi

    local aur_helper=""
    local aur_cmd=""

    if check_command yay; then
        aur_helper="yay"
        aur_cmd="yay -Sua --noconfirm"
    elif check_command paru; then
        aur_helper="paru"
        aur_cmd="paru -Sua --noconfirm"
    else
        log_warn "No AUR helper found (yay/paru)" "aur"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_PACKAGE} Updating AUR packages ($aur_helper)...${NC}"
    log_info "Updating AUR packages using $aur_helper" "aur"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "aur"

    [ "$AUR_DEVEL" -eq 1 ] && aur_cmd="$aur_cmd --devel"
    [ "$DRY_RUN" = "1" ] && aur_cmd="echo DRY-RUN: $aur_cmd"

    if ! retry "$aur_cmd" 2 3; then
        handle_error_with_rollback "AUR update failed ($aur_helper)" "AUR_ERROR" "aur"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} AUR packages updated successfully${NC}"

    local aur_updated=0
    if [ "$aur_helper" = "yay" ]; then
        aur_updated=$(yay -Qua 2>/dev/null | wc -l || echo 0)
    elif [ "$aur_helper" = "paru" ]; then
        aur_updated=$(paru -Qua 2>/dev/null | wc -l || echo 0)
    fi

    aur_updated=${aur_updated//[^0-9]/}
    aur_updated=${aur_updated:-0}
    TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + aur_updated))

    return 0
}

update_flatpak_packages() {
    if [ "$SKIP_FLATPAK" -eq 1 ]; then
        log_info "Skipping Flatpak updates" "flatpak"
        return 0
    fi

    if ! check_command flatpak; then
        log_warn "Flatpak not found" "flatpak"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_PACKAGE} Updating Flatpak packages...${NC}"
    log_info "Updating Flatpak packages" "flatpak"

    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "flatpak"

    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: flatpak update -y"
    elif ! flatpak update -y; then
        handle_error_with_rollback "Flatpak update failed" "FLATPAK_ERROR" "flatpak"
        return 1
    fi

    [ "$DRY_RUN" = "1" ] && echo "DRY-RUN: flatpak uninstall --unused -y" || flatpak uninstall --unused -y

    v_echo "${GREEN}${ICON_CHECK} Flatpak packages updated successfully${NC}"

    return 0
}

update_snap_packages() {
    if [ "$SKIP_SNAP" -eq 1 ]; then
        log_info "Skipping Snap updates" "snap"
        return 0
    fi

    if ! check_command snap; then
        log_warn "Snap not found" "snap"
        return 0
    fi

    # Check if snapd service is running
    if ! systemctl is-active snapd.socket >/dev/null 2>&1; then
        log_warn "Snapd service not running - skipping Snap updates" "snap"
        v_echo "${YELLOW}${ICON_WARN} Snapd service unavailable, skipping Snap updates${NC}"
        echo -e "${DIM}  Tip: Start snapd with: ${CYAN}sudo systemctl start snapd.socket${NC}"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_PACKAGE} Updating Snap packages...${NC}"
    log_info "Updating Snap packages" "snap"

    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: snap refresh"
    elif ! sudo snap refresh; then
        handle_error_with_rollback "Snap update failed" "SNAP_ERROR" "snap"
        return 1
    fi

    v_echo "${GREEN}${ICON_CHECK} Snap packages updated successfully${NC}"
    return 0
}

perform_system_cleanup() {
    if [ "$SKIP_CLEANUP" -eq 1 ]; then
        log_info "Skipping system cleanup" "cleanup"
        return 0
    fi

    v_echo "\n${CYAN}${ICON_CLEANUP} Performing system cleanup...${NC}"
    log_info "Starting system cleanup" "cleanup"

    echo -e "${BLUE}${ICON_PACKAGE} Cleaning package cache...${NC}"
    local cache_size_before=$(du -sm /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}' || echo "0")
    cache_size_before=${cache_size_before//[^0-9]/}
    cache_size_before=${cache_size_before:-0}

    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: sudo pacman -Sc --noconfirm"
    else
        if sudo pacman -Sc --noconfirm; then
            local cache_size_after=$(du -sm /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}' || echo "0")
            cache_size_after=${cache_size_after//[^0-9]/}
            cache_size_after=${cache_size_after:-0}
            log_message "Package cache cleaned (Before: ${cache_size_before} MiB, After: ${cache_size_after} MiB)"
            v_echo "${GREEN}${ICON_CHECK} Package cache cleaned (${cache_size_before} → ${cache_size_after} MiB)${NC}"
        fi
    fi

    echo -e "${BLUE}${ICON_PACKAGE} Checking for orphaned packages...${NC}"
    local orphans=""
    if orphans=$(pacman -Qtdq 2>/dev/null) && [ -n "$orphans" ]; then
        local orphan_count=$(echo "$orphans" | wc -l | tr -d ' ')
        orphan_count=${orphan_count:-0}
        v_echo "${YELLOW}Found $orphan_count orphaned packages${NC}"
        if [ "$DRY_RUN" = "1" ]; then
            echo "DRY-RUN: sudo pacman -Rns $(pacman -Qtdq) --noconfirm"
        else
            if sudo pacman -Rns $(pacman -Qtdq) --noconfirm; then
                log_message "$orphan_count orphaned packages removed"
                v_echo "${GREEN}${ICON_CHECK} Orphaned packages removed successfully${NC}"
            fi
        fi
    else
        v_echo "${GREEN}${ICON_CHECK} No orphaned packages found${NC}"
    fi

    echo -e "${BLUE}${ICON_CLEANUP} Cleaning system journals...${NC}"
    local journal_size_before=$(du -sm /var/log/journal 2>/dev/null | awk '{print $1}' || echo "0")
    journal_size_before=${journal_size_before//[^0-9]/}
    journal_size_before=${journal_size_before:-0}

    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: sudo journalctl --vacuum-time=7d"
    elif sudo journalctl --vacuum-time=7d; then
        local journal_size_after=$(du -sm /var/log/journal 2>/dev/null | awk '{print $1}' || echo "0")
        journal_size_after=${journal_size_after//[^0-9]/}
        journal_size_after=${journal_size_after:-0}
        log_message "Journal logs cleaned (Before: ${journal_size_before} MiB, After: ${journal_size_after} MiB)"
        v_echo "${GREEN}${ICON_CHECK} Journal cleaned (${journal_size_before} → ${journal_size_after} MiB)${NC}"
    fi

    # New Topgrade-inspired cleanups
    if [ "$SKIP_CARGO" -eq 0 ] && check_command cargo; then
        echo -e "${BLUE}${ICON_LANG} Cleaning Cargo cache...${NC}"
        cargo cache -a || true
    fi

    if [ "$SKIP_NPM" -eq 0 ] && check_command npm; then
        echo -e "${BLUE}${ICON_LANG} Cleaning Npm cache...${NC}"
        npm cache clean --force || true
    fi

    # NEW: Additional cleanups
    if [ "$SKIP_HOMEBREW" -eq 0 ] && check_command brew; then
        echo -e "${BLUE}${ICON_LANG} Cleaning Homebrew...${NC}"
        brew cleanup || true
    fi

    if [ "$SKIP_GO" -eq 0 ] && check_command go; then
        echo -e "${BLUE}${ICON_LANG} Cleaning Go module cache...${NC}"
        go clean -modcache || true
    fi

    if [ "$SKIP_DOCKER" -eq 0 ] && (check_command podman || check_command docker); then
        local tool=$(check_command podman && echo "podman" || echo "docker")
        echo -e "${BLUE}${ICON_PACKAGE} Pruning $tool unused resources...${NC}"
        sudo $tool system prune -f || true
    fi

    # NEW: More cleanups for additional handlers
    if [ "$SKIP_NIX" -eq 0 ] && (check_command nix || check_command lix); then
        local tool=$(check_command lix && echo "lix" || echo "nix")
        echo -e "${BLUE}${ICON_PACKAGE} Garbage collecting $tool...${NC}"
        $tool-collect-garbage -d || true
    fi

    if [ "$SKIP_OPAM" -eq 0 ] && check_command opam; then
        echo -e "${BLUE}${ICON_LANG} Cleaning Opam...${NC}"
        opam clean || true
    fi

    if [ "$SKIP_YARN" -eq 0 ] && check_command yarn; then
        echo -e "${BLUE}${ICON_LANG} Cleaning Yarn cache...${NC}"
        yarn cache clean || true
    fi

    if [ "$SKIP_RUSTUP" -eq 0 ] && check_command rustup; then
        echo -e "${BLUE}${ICON_LANG} Cleaning Rustup...${NC}"
        rustup self update --cleanup || true
    fi

    if [ "$SKIP_GUIX" -eq 0 ] && check_command guix; then
        echo -e "${BLUE}${ICON_PACKAGE} Garbage collecting Guix...${NC}"
        guix gc || true
    fi

    # Add more cleanups as needed

    return 0
}

snapshot_pre() {
    case "$SNAPSHOT_TOOL" in
    timeshift)
        [ "$DRY_RUN" = "1" ] && echo "DRY-RUN: timeshift --create --comments 'pre-update $(date)'" || sudo timeshift --create --comments "pre-update $(date)" 2>/dev/null || true
        ;;
    snapper)
        [ "$DRY_RUN" = "1" ] && echo "DRY-RUN: snapper create -t pre -d 'pre-update $(date)'" || sudo snapper create -t pre -d "pre-update $(date)" 2>/dev/null || true
        ;;
    esac
}

snapshot_post() {
    case "$SNAPSHOT_TOOL" in
    timeshift)
        [ "$DRY_RUN" = "1" ] && echo "DRY-RUN: timeshift --create --comments 'post-update $(date)'" || sudo timeshift --create --comments "post-update $(date)" 2>/dev/null || true
        ;;
    snapper)
        [ "$DRY_RUN" = "1" ] && echo "DRY-RUN: snapper create -t post -d 'post-update $(date)'" || sudo snapper create -t post -d "post-update $(date)" 2>/dev/null || true
        ;;
    esac
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # CRITICAL FIX: Initialize ALL numeric variables EARLY
    START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    START_EPOCH=$(date +%s)
    END_TIME=""
    TOTAL_PACKAGES_UPDATED=0
    FAILED_OPERATIONS=0

    log_audit "Starting system update process" "main"

    # Print fancy header
    echo -e "${BLUE}${BOLD}"
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║          System Update Manager v4.0 - Enhanced Edition               ║
║    A comprehensive update manager for Arch-based distributions       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    # Ask for upgrade method if not specified and in interactive mode
    if [ "$NONINTERACTIVE" -eq 0 ] && [ "$ALLOW_DOWNGRADE" -eq 0 ]; then
        echo -e "${CYAN}${BOLD}Select Upgrade Method:${NC}"
        echo -e "  ${GREEN}1)${NC} Standard upgrade (${CYAN}pacman -Syu${NC}) - Recommended"
        echo -e "  ${YELLOW}2)${NC} Allow downgrades (${CYAN}pacman -Syud${NC}) - For resolving version conflicts"
        echo ""

        local upgrade_choice=""
        while true; do
            read -p "Enter your choice (1-2, default: 1): " upgrade_choice
            upgrade_choice=${upgrade_choice:-1}

            case "$upgrade_choice" in
            1)
                ALLOW_DOWNGRADE=0
                echo -e "${GREEN}Using standard upgrade (pacman -Syu)${NC}\n"
                break
                ;;
            2)
                ALLOW_DOWNGRADE=1
                echo -e "${YELLOW}Using downgrade mode (pacman -Syud)${NC}\n"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
                ;;
            esac
        done
    fi

    # Display configuration
    echo -e "${CYAN}${BOLD}Configuration:${NC}"
    echo -e "  Distro: $DISTRO_BASE | Parallel: $PARALLEL_UPDATES | Rollback: $ROLLBACK_ENABLED"
    echo -e "  Dry Run: $DRY_RUN | Skip AUR: $SKIP_AUR | Skip Flatpak: $SKIP_FLATPAK"
    if [ "$ALLOW_DOWNGRADE" -eq 1 ]; then
        echo -e "  ${YELLOW}Upgrade Mode: Allow Downgrades (pacman -Syud)${NC}"
    else
        echo -e "  Upgrade Mode: Standard (pacman -Syu)"
    fi
    echo -e "  Topgrade Skips: Firmware:$SKIP_FIRMWARE Git:$SKIP_GIT Cargo:$SKIP_CARGO Pip:$SKIP_PIP etc."
    # NEW: Extend config display
    echo -e "  Additional Skips: Homebrew:$SKIP_HOMEBREW Go:$SKIP_GO Haskell:$SKIP_HASKELL Lua:$SKIP_LUA Docker:$SKIP_DOCKER Neovim:$SKIP_NEOVIM"
    # NEW: More skips display
    echo -e "  Extended Skips: Nix:$SKIP_NIX Opam:$SKIP_OPAM Vcpkg:$SKIP_VCPKG Yarn:$SKIP_YARN Rustup:$SKIP_RUSTUP Tmux:$SKIP_TMUX Vim:$SKIP_VIM Starship:$SKIP_STARSHIP Guix:$SKIP_GUIX"
    echo ""

    # Start sudo keepalive
    start_sudo_keepalive

    # Detect environment
    detect_environment

    # Check network
    if ! check_network; then
        log_error "Network check failed" "main"
        exit 1
    fi

    # Backup configurations
    backup_configs

    # Update system packages
    if ! update_system_packages; then
        log_warn "System package update encountered issues" "main"
    fi

    # Update AUR packages
    if ! update_aur_packages; then
        log_warn "AUR update encountered issues" "main"
    fi

    # Update Flatpak packages
    if ! update_flatpak_packages; then
        log_warn "Flatpak update encountered issues" "main"
    fi

    # Update Snap packages
    if ! update_snap_packages; then
        log_warn "Snap update encountered issues" "main"
    fi

    # Topgrade-inspired updates
    if ! update_firmware; then
        log_warn "Firmware update encountered issues" "main"
    fi

    if ! update_git_repos; then
        log_warn "Git repos update encountered issues" "main"
    fi

    if ! update_cargo; then
        log_warn "Cargo update encountered issues" "main"
    fi

    if ! update_pip; then
        log_warn "Pip update encountered issues" "main"
    fi

    if ! update_npm; then
        log_warn "Npm update encountered issues" "main"
    fi

    if ! update_gem; then
        log_warn "Gem update encountered issues" "main"
    fi

    if ! update_composer; then
        log_warn "Composer update encountered issues" "main"
    fi

    if ! update_shell_configs; then
        log_warn "Shell configs update encountered issues" "main"
    fi

    if ! update_vscode_extensions; then
        log_warn "VS Code extensions update encountered issues" "main"
    fi

    if ! update_custom_commands; then
        log_warn "Custom commands encountered issues" "main"
    fi

    # NEW: Additional Topgrade updates
    if ! update_homebrew; then
        log_warn "Homebrew update encountered issues" "main"
    fi

    if ! update_go; then
        log_warn "Go update encountered issues" "main"
    fi

    if ! update_haskell; then
        log_warn "Haskell update encountered issues" "main"
    fi

    if ! update_lua; then
        log_warn "Lua update encountered issues" "main"
    fi

    if ! update_docker; then
        log_warn "Docker/Podman update encountered issues" "main"
    fi

    if ! update_neovim; then
        log_warn "Neovim update encountered issues" "main"
    fi

    # NEW: More Topgrade and Guix updates
    if ! update_nix; then
        log_warn "Nix/Lix update encountered issues" "main"
    fi

    if ! update_opam; then
        log_warn "Opam update encountered issues" "main"
    fi

    if ! update_vcpkg; then
        log_warn "Vcpkg update encountered issues" "main"
    fi

    if ! update_yarn; then
        log_warn "Yarn update encountered issues" "main"
    fi

    if ! update_rustup; then
        log_warn "Rustup update encountered issues" "main"
    fi

    if ! update_tmux; then
        log_warn "Tmux update encountered issues" "main"
    fi

    if ! update_vim; then
        log_warn "Vim update encountered issues" "main"
    fi

    if ! update_starship; then
        log_warn "Starship update encountered issues" "main"
    fi

    if ! update_guix; then
        log_warn "Guix update encountered issues" "main"
    fi

    # Perform system cleanup
    if ! perform_system_cleanup; then
        log_warn "System cleanup encountered issues" "main"
    fi

    # Finalize - CRITICAL FIX: Safe arithmetic operations
    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    local end_epoch=$(date +%s)

    # Ensure START_EPOCH is set properly
    START_EPOCH=${START_EPOCH:-0}

    # Safe duration calculation
    local duration=$((end_epoch - START_EPOCH))
    [ "$duration" -lt 0 ] && duration=0

    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    # Check if any packages were removed during automatic fixes
    if [ -f /tmp/update-script-removed-pkgs.txt ]; then
        local removed_pkgs=$(cat /tmp/update-script-removed-pkgs.txt | tr ' ' '\n' | sort -u)
        local git_conflict_pkgs=""
        local aur_pkgs=""

        # Separate Git conflict packages from AUR packages
        for pkg in $removed_pkgs; do
            # Check if this package has a -git version installed (indicating it was a Git conflict)
            local base_name=$(echo "$pkg" | sed -E 's/-[0-9].*$//')
            if pacman -Q "${base_name}-git" &>/dev/null 2>&1; then
                git_conflict_pkgs="$git_conflict_pkgs $pkg"
            else
                aur_pkgs="$aur_pkgs $pkg"
            fi
        done

        # Display Git conflict packages
        if [ -n "$git_conflict_pkgs" ]; then
            echo -e "\n${YELLOW}${ICON_WARN} ${BOLD}Important: Regular Packages Removed (Git Conflicts)${NC}"
            echo -e "${YELLOW}The following regular packages were removed because they conflict with installed -git versions:${NC}"
            for pkg in $git_conflict_pkgs; do
                local base_name=$(echo "$pkg" | sed -E 's/-[0-9].*$//')
                local git_version=$(pacman -Q "${base_name}-git" 2>/dev/null | awk '{print $2}')
                echo -e "  • ${CYAN}$pkg${NC} (kept ${GREEN}${base_name}-git-${git_version}${NC})"
            done
            echo ""
            echo -e "${GREEN}Note:${NC} -git versions are kept as they're typically more up-to-date."
            echo -e "${DIM}If you need the regular versions, you can install them after removing the -git versions:${NC}"
            for pkg in $git_conflict_pkgs; do
                local base_name=$(echo "$pkg" | sed -E 's/-[0-9].*$//')
                echo -e "  ${CYAN}sudo pacman -R ${base_name}-git && sudo pacman -S ${base_name}${NC}"
            done
            echo ""
        fi

        # Display AUR packages
        if [ -n "$aur_pkgs" ]; then
            echo -e "\n${YELLOW}${ICON_WARN} ${BOLD}Important: AUR Packages Removed${NC}"
            echo -e "${YELLOW}The following AUR packages were temporarily removed to resolve dependency conflicts:${NC}"
            for pkg in $aur_pkgs; do
                echo -e "  • ${CYAN}$pkg${NC}"
            done
            echo ""
            echo -e "${GREEN}You can reinstall them now with:${NC}"
            for pkg in $aur_pkgs; do
                echo -e "  ${CYAN}yay -S $pkg${NC}  # or paru -S $pkg"
            done
            echo ""
        fi

        # Clean up temp file
        rm -f /tmp/update-script-removed-pkgs.txt
    fi

    # Print summary
    echo -e "\n${BLUE}${BOLD}Update Summary:${NC}"
    echo -e "  ${ICON_COMPLETE} Total packages updated: $TOTAL_PACKAGES_UPDATED"
    echo -e "  ${ICON_ERROR} Failed operations: $FAILED_OPERATIONS"
    echo -e "  ${ICON_CHECK} Start time: $START_TIME"
    echo -e "  ${ICON_CHECK} End time: $END_TIME"
    echo -e "  ${ICON_CHECK} Duration: ${minutes}m ${seconds}s"
    echo -e "  📁 Logs: $LOG_FILE"
    echo -e "  💾 Backups: $BACKUP_DIR"

    if [ "$FAILED_OPERATIONS" -gt 0 ]; then
        echo -e "\n${RED}${BOLD}⚠️  Some operations failed. Check logs for details.${NC}"
        exit 1
    else
        echo -e "\n${GREEN}${BOLD}${ICON_COMPLETE} Update process completed successfully!${NC}"
        exit 0
    fi
}

# Run main function with error handling
if [ $# -eq 0 ] || [ "${1:-}" != "--help" ] && [ "${1:-}" != "--version" ]; then
    main "$@"
fi
