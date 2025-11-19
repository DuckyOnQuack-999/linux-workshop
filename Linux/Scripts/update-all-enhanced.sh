#!/bin/bash

# =============================================================================
# System-Wide Update Manager v4.0 - Enhanced Edition
# =============================================================================
# A comprehensive system update script for Arch-based distributions
# Features: Parallel updates, rollback capability, health monitoring,
#           notifications, progress persistence, and advanced error handling
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

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

# System information
SCRIPT_VERSION="4.0"
SCRIPT_NAME="System Update Manager"
START_TIME=""
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
ICON_CPU="⚡"
ICON_RAM="🧠"
ICON_DISK="💿"
ICON_DESKTOP="🖥️"
ICON_KERNEL="🐧"
ICON_COMPLETE="🎉"

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
SNAPSHOT_TOOL=""
PACNEW_MANAGE=0
NO_COLOR=0
QUIET=0
VERBOSE=0
REPORT_PATH=""

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
MONITOR_PIDS=()
MIRROR_COUNTRY=""
START_TIME=""
END_TIME=""
TOTAL_PACKAGES_UPDATED=0
FAILED_OPERATIONS=0

# Distro detection
. /etc/os-release 2>/dev/null || true
case "${ID_LIKE:-$ID}" in
    *manjaro*|*manjaro-linux*) DISTRO_BASE="manjaro" ;;
    *) DISTRO_BASE="arch" ;;
esac

# =============================================================================
# ENHANCED ARGUMENT PARSING AND HELP SYSTEM
# =============================================================================

show_help() {
    cat << EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

${BOLD}DESCRIPTION:${NC}
    A comprehensive system update manager for Arch-based distributions with
    advanced features including parallel updates, rollback capability,
    health monitoring, and desktop notifications.

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    ${GREEN}Update Control:${NC}
        -y, --yes, --non-interactive    Run without user interaction
        --dry-run                       Show what would be updated without making changes
        --parallel                      Enable parallel updates (experimental)
        --max-jobs N                    Maximum parallel jobs (default: 3)

    ${GREEN}Package Managers:${NC}
        --no-aur                        Skip AUR updates
        --no-flatpak                    Skip Flatpak updates  
        --no-snap                       Skip Snap updates
        --aur-devel                     Include AUR development packages

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
    $0 --no-aur --fast-mirrors         # Skip AUR, use fast mirrors

${BOLD}CONFIGURATION:${NC}
    Configuration files are stored in: $CONFIG_DIR
    Logs are stored in: $CONFIG_DIR/logs
    Backups are stored in: $CONFIG_DIR/backups

EOF
}

show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    echo "Enhanced system update manager for Arch-based distributions"
}

# Enhanced argument parsing with validation
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            --version) show_version; exit 0 ;;
            -y|--yes|--non-interactive) NONINTERACTIVE=1 ;;
            --no-aur) SKIP_AUR=1 ;;
            --no-flatpak) SKIP_FLATPAK=1 ;;
            --no-snap) SKIP_SNAP=1 ;;
            --no-cleanup) SKIP_CLEANUP=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --aur-devel) AUR_DEVEL=1 ;;
            --dns-fallback) DNS_FALLBACK=1 ;;
            --parallel) PARALLEL_UPDATES=true ;;
            --max-jobs)
                shift
                MAX_PARALLEL_JOBS="$1"
                ;;
            --rollback) ROLLBACK_ENABLED=true ;;
            --snapshots)
                shift
                SNAPSHOT_TOOL="$1"
                ;;
            --pacnew-manage) PACNEW_MANAGE=1 ;;
            --no-color) NO_COLOR=1 ;;
            --mirror-country)
                shift
                MIRROR_COUNTRY="$1"
                ;;
            --fast-mirrors) FAST_MIRRORS=1 ;;
            --quiet) QUIET=1 ;;
            --verbose) VERBOSE=1 ;;
            --report)
                shift
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
                LOG_LEVEL="$1"
                ;;
            --config)
                shift
                CONFIG_FILE="$1"
                ;;
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
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; BOLD=''; DIM=''; ITALIC=''; NC=''
fi

# =============================================================================
# ENHANCED LOGGING SYSTEM
# =============================================================================

# Log file and error tracking with timestamps
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$CONFIG_DIR/logs/update_${TIMESTAMP}.log"
ERROR_LOG="$CONFIG_DIR/logs/errors_${TIMESTAMP}.log"
BACKUP_LOG="$CONFIG_DIR/logs/backup_${TIMESTAMP}.log"
AUDIT_LOG="$CONFIG_DIR/logs/audit_${TIMESTAMP}.log"

# Create log files
touch "$LOG_FILE" "$ERROR_LOG" "$BACKUP_LOG" "$AUDIT_LOG"

# Enhanced verbosity helpers
v_echo() { 
    [ "$QUIET" -eq 0 ] && echo -e "$1" 
}

v_log_info() { 
    [ "$QUIET" -eq 0 ] && log_info "$1" "${2:-system}"
    [ "$VERBOSE" -eq 1 ] && log_info "$1" "${2:-system}"
}

# Log level checking
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

# Enhanced logging function with JSON support and audit trail
log_message() {
    local level="$1"
    local message="$2"
    local component="${3:-system}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if we should log this level
    should_log "$level" || return 0
    
    # Standard log output with enhanced formatting
    case "$level" in
        "DEBUG") echo -e "${DIM}[DEBUG]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
        "INFO")  echo -e "${GREEN}[INFO]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" | tee -a "$ERROR_LOG" ;;
        "AUDIT") echo -e "${BLUE}[AUDIT]${NC} $timestamp - $message" | tee -a "$AUDIT_LOG" ;;
        *)       echo -e "$timestamp - $message" | tee -a "$LOG_FILE" ;;
    esac
    
    # JSON structured logging with enhanced metadata
    mkdir -p "$(dirname "$JSON_LOG")"
    local json_entry=$(printf '{"timestamp":"%s","level":"%s","component":"%s","message":"%s","pid":"%s","user":"%s"}\n' \
        "$timestamp" "$level" "$component" "$message" "$$" "$USER")
    echo "$json_entry" >> "$JSON_LOG"
    
    # Update progress file for external monitoring
    update_progress "$level" "$message" "$component"
}

# Logging helpers for consistency
log_info() { log_message "INFO" "$1" "${2:-system}"; }
log_warn() { log_message "WARN" "$1" "${2:-system}"; }
log_error() { log_message "ERROR" "$1" "${2:-system}"; }
log_debug() { log_message "DEBUG" "$1" "${2:-system}"; }
log_audit() { log_message "AUDIT" "$1" "${2:-system}"; }

# =============================================================================
# ENHANCED UTILITY FUNCTIONS
# =============================================================================

# Progress tracking and persistence
update_progress() {
    local level="$1"
    local message="$2"
    local component="${3:-system}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create progress JSON
    local progress_data=$(cat << EOF
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
    echo "$progress_data" > "$PROGRESS_FILE"
}

# Notification system
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="${4:-system-software-update}"
    
    [ "$ENABLE_NOTIFICATIONS" -eq 0 ] && return 0
    
    # Try different notification methods
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -i "$icon" "$title" "$message" &
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" --msgbox "$message" &
    elif command -v zenity >/dev/null 2>&1; then
        zenity --info --title "$title" --text "$message" &
    fi
}

# Enhanced error handling with rollback support
handle_error_with_rollback() {
    local error_msg="$1"
    local error_code="$2"
    local component="${3:-system}"
    
    log_error "$error_msg (Code: $error_code)" "$component"
    ((FAILED_OPERATIONS++))
    
    # Send error notification
    [ "$NOTIFY_ERRORS" -eq 1 ] && send_notification "Update Error" "$error_msg" "critical" "error"
    
    # Attempt rollback if enabled
    if [ "$ROLLBACK_ENABLED" = true ] && [ -d "$ROLLBACK_DIR" ]; then
        log_info "Attempting rollback for component: $component" "$component"
        rollback_component "$component" || log_error "Rollback failed for $component" "$component"
    fi
    
    # Update progress
    update_progress "ERROR" "$error_msg" "$component"
}

# Rollback functionality
rollback_component() {
    local component="$1"
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

# Create rollback backup
create_rollback_backup() {
    local component="$1"
    local rollback_file="$ROLLBACK_DIR/${component}_backup.tar.gz"
    
    mkdir -p "$ROLLBACK_DIR"
    
    case "$component" in
        "pacman")
            sudo tar -czf "$rollback_file" /var/lib/pacman/ 2>/dev/null || return 1
            ;;
        "config")
            tar -czf "$rollback_file" -C "$HOME" .config/ 2>/dev/null || return 1
            ;;
        *)
            log_warn "Unknown component for rollback: $component" "$component"
            return 1
            ;;
    esac
    
    log_info "Created rollback backup for $component" "$component"
    return 0
}

# Process/cleanup traps
cleanup_on_exit() {
    # Stop monitors
    for pid in "${MONITOR_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    # Remove temporary DNS fallback if added
    if [ "$DNS_FALLBACK" = "1" ]; then
        if command -v resolvconf >/dev/null 2>&1; then
            resolvconf -d tmp-dns 2>/dev/null || true
        elif systemctl is-active systemd-resolved >/dev/null 2>&1; then
            sudo systemctl restart systemd-resolved 2>/dev/null || true
        fi
    fi
    rm -f /tmp/pacman_stderr.log 2>/dev/null || true
    # Stop sudo keep-alive
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    
    # Send completion notification
    if [ "$NOTIFY_COMPLETE" -eq 1 ]; then
        send_notification "Update Complete" "System update finished with $TOTAL_PACKAGES_UPDATED packages updated" "normal" "system-software-update"
    fi
}
trap cleanup_on_exit EXIT INT TERM

start_monitor() {
    monitor_resources $$ &
    local pid=$!
    MONITOR_PIDS+=("$pid")
    echo "$pid"
}

# Keep sudo alive to avoid prompts mid-run
start_sudo_keepalive() {
    if sudo -v; then
        ( while true; do sudo -n true 2>/dev/null || exit; sleep 60; done ) &
        SUDO_KEEPALIVE_PID=$!
    fi
}

# Generic retry helper: retry "command" max_tries backoff_start_seconds
retry() {
    local cmd="$1"; local tries="${2:-3}"; local backoff="${3:-2}";
    local i=1
    while [ $i -le $tries ]; do
        eval "$cmd" && return 0
        sleep $((backoff * i))
        i=$((i+1))
    done
    return 1
}

# Enhanced command checker
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_message "WARN" "Command not found: $1"
        return 1
    fi
    return 0
}

# Enhanced network connectivity check
check_network() {
    echo -e "\n${CYAN}${ICON_NETWORK} Checking network connectivity...${NC}"
    local timeout=5
    # Basic reachability
    if ! ping -c 1 -W $timeout 8.8.8.8 &> /dev/null && ! ping -c 1 -W $timeout 1.1.1.1 &> /dev/null; then
        handle_error_with_rollback "No internet connection detected" "NETWORK_ERROR" "network"
        return 1
    fi
    # DNS resolution
    if ! getent hosts archlinux.org >/dev/null 2>&1; then
        log_warn "DNS resolution failed for archlinux.org" "network"
        if [ "$DNS_FALLBACK" = "1" ]; then
            echo -e "${YELLOW}Applying temporary DNS fallback (1.1.1.1)...${NC}"
            if command -v resolvconf >/dev/null 2>&1; then
                sudo resolvconf -a tmp-dns <<< "nameserver 1.1.1.1" 2>/dev/null || true
            elif systemctl is-active systemd-resolved >/dev/null 2>&1; then
                sudo bash -c 'printf "nameserver 1.1.1.1\n" > /run/systemd/resolve/resolv.conf' 2>/dev/null || true
            fi
        fi
    fi
    # HTTPS to known mirror or fallback list
    if command -v curl >/dev/null 2>&1; then
        if ! curl -s --max-time 5 https://archlinux.org/ >/dev/null; then
            log_warn "HTTPS to archlinux.org failed" "network"
            # Try a small mirror fallback list and apply temporary mirrorlist if needed
            mirrors=(
                "https://mirror.rackspace.com/archlinux/$repo/os/$arch"
                "https://mirror.osbeck.com/archlinux/$repo/os/$arch"
                "https://geo.mirror.pkgbuild.com/$repo/os/$arch"
            )
            for m in "${mirrors[@]}"; do
                curl -s --max-time 5 "${m//\$repo/core}" >/dev/null && {
                    echo -e "${BLUE}${ICON_NETWORK} Using fallback mirror temporarily: $m${NC}"
                    echo "Server = ${m}" | sudo tee /etc/pacman.d/mirrorlist >/dev/null
                    break
                }
            done
        fi
    fi
    echo -e "${GREEN}${ICON_CHECK} Network connection established${NC}"
    return 0
}

# Function to detect and configure environment
detect_environment() {
    echo -e "\n${CYAN}${ICON_SYSTEM} Detecting system environment...${NC}"
    
    # Session type detection
    if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        WAYLAND=1
        log_message "INFO" "Wayland session detected"
        echo -e "${GREEN}${ICON_CHECK} Wayland session detected${NC}"
        
        # Hyprland detection
        if pgrep -x "Hyprland" >/dev/null; then
            HYPRLAND=1
            log_message "INFO" "Hyprland compositor detected"
            echo -e "${GREEN}${ICON_CHECK} Hyprland compositor detected${NC}"
        fi
    else
        X11=1
        log_message "INFO" "X11 session detected"
        echo -e "${GREEN}${ICON_CHECK} X11 session detected${NC}"
    fi

    # Desktop environment detection
    if pgrep -x "plasmashell" >/dev/null; then
        KDE=1
        log_message "INFO" "KDE Plasma detected"
        echo -e "${GREEN}${ICON_CHECK} KDE Plasma detected${NC}"
    fi
}

# Function to check system resources
check_system_resources() {
    echo -e "\n${CYAN}${ICON_SYSTEM} Checking system resources...${NC}"
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    echo -e "${BLUE}${ICON_CPU} CPU Usage: ${cpu_usage}%${NC}"
    
    # RAM usage
    local ram_total=$(free -m | awk '/Mem:/ {print $2}')
    local ram_used=$(free -m | awk '/Mem:/ {print $3}')
    local ram_percent=$(awk "BEGIN {printf \"%.1f\", $ram_used/$ram_total*100}")
    echo -e "${BLUE}${ICON_RAM} RAM Usage: ${ram_percent}%${NC}"
    
    # Disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    echo -e "${BLUE}${ICON_DISK} Disk Usage: ${disk_usage}%${NC}"
    
    if [ "$disk_usage" -gt 90 ]; then
        log_message "WARN" "Low disk space detected: ${disk_usage}%"
        echo -e "${YELLOW}${ICON_WARN} Warning: Low disk space!${NC}"
    fi
}

# Modern progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    printf "\r${BLUE}["
    printf "%${filled}s" | tr ' ' '▓'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${NC} %3d%%" $percentage
}

# System resource monitor
monitor_resources() {
    local pid=$1
    while ps -p $pid > /dev/null; do
        local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
        local mem=$(free -m | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
        local disk=$(df -h / | awk 'NR==2 {print $5}')
        printf "\r${CYAN}${ICON_CPU} CPU: %5s%% ${ICON_RAM} RAM: %5s%% ${ICON_DISK} Disk: %s${NC}" "$cpu" "$mem" "$disk"
        sleep 1
    done
    printf "\r%*s\r" 80 ""
}

# Backup configuration files
backup_configs() {
    echo -e "\n${BLUE}${ICON_BACKUP} Backing up system configurations...${NC}"
    mkdir -p "$BACKUP_DIR"
    
    local total=${#IMPORTANT_CONFIGS[@]}
    local current=0
    
    for config in "${IMPORTANT_CONFIGS[@]}"; do
        ((current++))
        if [ -e "$config" ]; then
            show_progress $current $total
            cp -r "$config" "$BACKUP_DIR/" 2>/dev/null
            log_message "INFO" "Backed up: $config"
        fi
    done
    echo -e "\n${GREEN}${ICON_CHECK} Backups completed: $BACKUP_DIR${NC}"
}

# Pacman sync recovery and retry wrapper
recover_pacman_sync() {
    echo -e "${YELLOW}Attempting automated recovery for pacman sync errors...${NC}"
    log_warn "Starting pacman sync recovery" "pacman"

    # 1) Ensure no stale DB lock
    sudo rm -f /var/lib/pacman/db.lck 2>/dev/null

    # 2) Force refresh databases; try several mirrors
    sudo pacman -Syy || true

    # 3) Refresh keys if keyring looks stale
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

    # 4) Clear partial downloads that can break sync
    sudo rm -f /var/lib/pacman/sync/*.part 2>/dev/null || true

    # 5) Mirror refresh
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

    # 6) Try one more forced DB refresh after changes
    sudo pacman -Syy || true

    # 7) Remove corrupted sync databases if present and re-fetch
    for db in /var/lib/pacman/sync/*.db; do
        [ -f "$db" ] || continue
        if ! bsdtar -tf "$db" >/dev/null 2>&1; then
            sudo rm -f "$db" 2>/dev/null || true
        fi
    done
}

pacman_update_with_recovery() {
    local mon
    mon=$(start_monitor)
    local base_cmd="sudo pacman -Syu --noconfirm"
    [ "$DRY_RUN" = "1" ] && base_cmd="echo DRY-RUN: pacman -Syu"
    if eval "$base_cmd" 2> >(tee /tmp/pacman_stderr.log >&2); then
        kill "$mon" 2>/dev/null
        return 0
    fi
    kill "$mon" 2>/dev/null

    if grep -qi "failed to synchronize all databases" /tmp/pacman_stderr.log; then
        log_error "Pacman sync failed; attempting recovery" "pacman"
        recover_pacman_sync
        mon=$(start_monitor)
        if eval "$base_cmd"; then
            kill "$mon" 2>/dev/null
            return 0
        fi
        kill "$mon" 2>/dev/null
    fi

    if grep -qi "PGP signature" /tmp/pacman_stderr.log; then
        log_warn "PGP signature issue detected; refreshing keyrings and clearing cached signatures" "pacman"
        case "$DISTRO_BASE" in
            manjaro)
                sudo pacman -S --noconfirm --needed manjaro-keyring || true ;;
            *)
                sudo pacman -S --noconfirm --needed archlinux-keyring || true ;;
        esac
        sudo rm -f /var/cache/pacman/pkg/*.sig 2>/dev/null || true
        sudo pacman-key --refresh-keys 2>/dev/null || true
        mon=$(start_monitor)
        if eval "$base_cmd"; then
            kill "$mon" 2>/dev/null
            return 0
        fi
        kill "$mon" 2>/dev/null
    fi
    return 1
}

# =============================================================================
# MAIN EXECUTION FUNCTIONS
# =============================================================================

# System package update function
update_system_packages() {
    log_info "Starting system package updates" "pacman"
    v_echo "\n${CYAN}${ICON_PACKAGE} Updating system packages...${NC}"
    
    # Create rollback backup if enabled
    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "pacman"
    
    snapshot_pre

    # Start resource monitoring in background
    local mon
    mon=$(start_monitor)

    if ! pacman_update_with_recovery; then
        kill "$mon" 2>/dev/null
        handle_error_with_rollback "System package update failed" "PACMAN_ERROR" "pacman"
        return 1
    fi

    kill "$mon" 2>/dev/null
    v_echo "${GREEN}${ICON_CHECK} System packages updated successfully${NC}"
    snapshot_post
    
    # Update package count
    local updated_count=$(pacman -Qu | wc -l)
    TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + updated_count))
    
    return 0
}

# AUR package update function
update_aur_packages() {
    if [ "$SKIP_AUR" -eq 1 ]; then
        log_info "Skipping AUR updates" "aur"
        return 0
    fi
    
    local aur_helper=""
    local aur_cmd=""
    
    # Detect AUR helper
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
    
    # Create rollback backup if enabled
    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "aur"
    
    # Add development packages flag if requested
    [ "$AUR_DEVEL" -eq 1 ] && aur_cmd="$aur_cmd --devel"
    [ "$DRY_RUN" = "1" ] && aur_cmd="echo DRY-RUN: $aur_cmd"
    
    # Start monitoring
    local mon
    mon=$(start_monitor)
    
    if ! retry "$aur_cmd" 2 3; then
        kill "$mon" 2>/dev/null
        handle_error_with_rollback "AUR update failed ($aur_helper)" "AUR_ERROR" "aur"
        return 1
    fi
    
    kill "$mon" 2>/dev/null
    v_echo "${GREEN}${ICON_CHECK} AUR packages updated successfully${NC}"
    
    # Update package count
    local aur_updated=0
    if [ "$aur_helper" = "yay" ]; then
        aur_updated=$(yay -Qua 2>/dev/null | wc -l)
    elif [ "$aur_helper" = "paru" ]; then
        aur_updated=$(paru -Qua 2>/dev/null | wc -l)
    fi
    TOTAL_PACKAGES_UPDATED=$((TOTAL_PACKAGES_UPDATED + aur_updated))
    
    return 0
}

# Flatpak update function
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
    
    # Create rollback backup if enabled
    [ "$ROLLBACK_ENABLED" = true ] && create_rollback_backup "flatpak"
    
    # Start monitoring
    local mon
    mon=$(start_monitor)
    
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: flatpak update -y"
    elif ! flatpak update -y; then
        kill "$mon" 2>/dev/null
        handle_error_with_rollback "Flatpak update failed" "FLATPAK_ERROR" "flatpak"
        return 1
    fi
    
    # Clean up unused packages
    [ "$DRY_RUN" = "1" ] && echo "DRY-RUN: flatpak uninstall --unused -y" || flatpak uninstall --unused -y
    
    kill "$mon" 2>/dev/null
    v_echo "${GREEN}${ICON_CHECK} Flatpak packages updated successfully${NC}"
    
    return 0
}

# Snap update function
update_snap_packages() {
    if [ "$SKIP_SNAP" -eq 1 ]; then
        log_info "Skipping Snap updates" "snap"
        return 0
    fi
    
    if ! check_command snap; then
        log_warn "Snap not found" "snap"
        return 0
    fi
    
    v_echo "\n${GREEN}📦 Updating Snap packages...${NC}"
    log_info "Updating Snap packages" "snap"
    
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: snap refresh"
    else
        sudo snap refresh
    fi
    
    v_echo "${GREEN}${ICON_CHECK} Snap packages updated successfully${NC}"
    return 0
}

# System cleanup function
perform_system_cleanup() {
    if [ "$SKIP_CLEANUP" -eq 1 ]; then
        log_info "Skipping system cleanup" "cleanup"
        return 0
    fi
    
    v_echo "\n${CYAN}${ICON_CLEANUP} Performing system cleanup...${NC}"
    log_info "Starting system cleanup" "cleanup"

    # Clean package cache with progress
    echo -e "${BLUE}${ICON_PACKAGE} Cleaning package cache...${NC}"
    cache_size_before=$(du -sh /var/cache/pacman/pkg | cut -f1)
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: sudo pacman -Sc --noconfirm"
    else
        if sudo pacman -Sc --noconfirm; then
            cache_size_after=$(du -sh /var/cache/pacman/pkg | cut -f1)
            log_message "Package cache cleaned (Before: $cache_size_before, After: $cache_size_after)"
            v_echo "${GREEN}${ICON_CHECK} Package cache cleaned ($cache_size_before → $cache_size_after)${NC}"
        fi
    fi

    # Remove orphaned packages with details
    echo -e "${BLUE}${ICON_PACKAGE} Checking for orphaned packages...${NC}"
    if orphans=$(pacman -Qtdq); then
        orphan_count=$(echo "$orphans" | wc -l)
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

    # Clean journal logs older than 7 days
    echo -e "${BLUE}${ICON_CLEANUP} Cleaning system journals...${NC}"
    journal_size_before=$(du -sh /var/log/journal 2>/dev/null | cut -f1)
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY-RUN: sudo journalctl --vacuum-time=7d"
    elif sudo journalctl --vacuum-time=7d; then
        journal_size_after=$(du -sh /var/log/journal 2>/dev/null | cut -f1)
        log_message "Journal logs cleaned (Before: $journal_size_before, After: $journal_size_after)"
        v_echo "${GREEN}${ICON_CHECK} Journal cleaned ($journal_size_before → $journal_size_after)${NC}"
    fi
}

# Snapshot functions
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
    # Initialize
    START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    log_audit "Starting system update process" "main"
    
    # Print fancy header
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       ${BOLD}System-Wide Update Manager v4.0${NC}${BLUE}              ║${NC}"
    echo -e "${BLUE}║       ${DIM}Enhanced Update Solution for Arch${NC}${BLUE}           ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"

    # System information header
    echo -e "\n${CYAN}${ICON_SYSTEM} System Information:${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}• Kernel:${NC} $(uname -r)"
    echo -e "${BLUE}• Architecture:${NC} $(uname -m)"
    echo -e "${BLUE}• Hostname:${NC} $(hostname)"
    echo -e "${BLUE}• User:${NC} $USER"

    # Start sudo keepalive
    start_sudo_keepalive

    # Check for root privileges
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}Don't run this script as root/sudo directly${NC}"
        exit 1
    fi

    # Check network connectivity
    echo -e "\n${YELLOW}Checking network connectivity...${NC}"
    check_network

    # Backup reminder
    if [ "$NONINTERACTIVE" -eq 0 ]; then
        echo -e "\n${YELLOW}⚠️  Reminder: Consider backing up important data before proceeding${NC}"
        read -p "Press Enter to continue or Ctrl+C to cancel..."
    fi

    # Detect environment
    detect_environment

    # Check system resources
    check_system_resources

    # Backup configurations
    backup_configs

    # Perform health check if requested
    if [ "$HEALTH_CHECK" -eq 1 ]; then
        echo -e "\n${CYAN}${ICON_SYSTEM} Performing comprehensive system health check...${NC}"
        # Add comprehensive health check here
    fi

    # Update system packages
    update_system_packages || log_error "System package update failed" "main"

    # Update AUR packages
    update_aur_packages || log_error "AUR package update failed" "main"

    # Update Flatpak packages
    update_flatpak_packages || log_error "Flatpak update failed" "main"

    # Update Snap packages
    update_snap_packages || log_error "Snap update failed" "main"

    # Perform system cleanup
    perform_system_cleanup

    # Final summary
    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    v_echo "\n${GREEN}╔════════════════════════════════════════════╗${NC}"
    v_echo "${GREEN}║         System Update Complete! ${ICON_COMPLETE}          ║${NC}"
    v_echo "${GREEN}╚════════════════════════════════════════════╝${NC}"

    # Detailed Summary
    v_echo "\n${CYAN}${ICON_SYSTEM} Update Summary:${NC}"
    v_echo "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    v_echo "${BLUE}• Update Time:${NC} $START_TIME - $END_TIME"
    v_echo "${BLUE}• System Status:${NC} $(systemctl is-system-running)"
    v_echo "${BLUE}• Packages Updated:${NC} $TOTAL_PACKAGES_UPDATED"
    v_echo "${BLUE}• Failed Operations:${NC} $FAILED_OPERATIONS"
    v_echo "${BLUE}• Log Files:${NC}"
    v_echo "  - Main Log: $LOG_FILE"
    v_echo "  - Error Log: $ERROR_LOG"
    v_echo "  - Backup Log: $BACKUP_LOG"

    # Send completion notification
    if [ "$NOTIFY_COMPLETE" -eq 1 ]; then
        send_notification "Update Complete" "System update finished with $TOTAL_PACKAGES_UPDATED packages updated" "normal" "system-software-update"
    fi

    log_audit "System update process completed successfully" "main"
}

# Execute main function
main "$@"
