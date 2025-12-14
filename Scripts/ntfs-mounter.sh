#!/bin/bash

###############################################################################
# Enhanced NTFS Drive Mounter
# Author: @DuckyOnQuack-999
# Repository: https://github.com/DuckyOnQuack-999/dotfiles
# License: MIT
#
# Description:
# Automatically detects and mounts NTFS drives with advanced features 
# and proper permissions. Part of DuckyOnQuack-999's dotfiles collection.
#
# Features:
# - Automatic NTFS drive detection and mounting
# - Interactive mode with user-friendly interface
# - Batch operations support
# - Advanced error handling and recovery
# - Progress visualization
# - Detailed logging with rotation
# - System health checks
#
# Version: 1.0.0
# Release Date: 2024
#
# System Requirements:
# - Linux-based OS
# - bash 4.0+
# - ntfs-3g
# - util-linux
# - coreutils
#
# Dependencies:
# - blkid
# - mount
# - ntfs-3g
# - grep
# - awk
# - ntfsfix (optional)
# - ntfsinfo (optional)
#
# Support:
# For issues and feature requests:
# https://github.com/DuckyOnQuack-999/dotfiles/issues
#
# Part of DuckyOnQuack-999's dotfiles:
# https://github.com/DuckyOnQuack-999/dotfiles
#
###############################################################################
# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Initialize debug mode
debug_mode=false

# Get script name
if ! SCRIPT_NAME=$(basename "$0"); then
    echo "Error: Failed to get script name" >&2
    exit 1
fi
readonly SCRIPT_NAME

# Directory and file paths
declare -r LOG_DIR="/var/log/ntfs-mounter"
declare -r LOG_FILE="$LOG_DIR/ntfs-mounter.log"
declare -r BACKUP_DIR="/var/backups/ntfs-mounter"

# Configuration constants
declare -r MAX_LOG_SIZE=$((10*1024*1024))  # 10MB
declare -r MAX_LOG_FILES=5
declare -r MOUNT_OPTIONS="rw,big_writes,windows_names,noatime,x-gvfs-show"

# Color definitions
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r WHITE='\033[1;37m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m'  # No Color

# UI Components
declare -r SPINNER_FRAMES=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
declare -r SPINNER_DELAY=0.1
declare -r PROGRESS_WIDTH=40

# UI Helper Functions
spinner_start() {
    local msg="$1"
    [[ -t 1 ]] && tput civis  # Hide cursor only if output is terminal
    local i=0
    while true; do
        printf "\r${BLUE}${SPINNER_FRAMES[i]}${NC} %s..." "$msg"
        ((i=(i+1)%8))
        sleep $SPINNER_DELAY
    done &
    echo $! > /tmp/spinner.pid
}

spinner_stop() {
    local pid
    pid=$(cat /tmp/spinner.pid)
    kill "$pid" 2>/dev/null
    rm -f /tmp/spinner.pid
    [[ -t 1 ]] && tput cnorm  # Show cursor only if output is terminal
    echo
}

progress_bar() {
    local current=$1
    local total=$2
    local prefix=${3:-"Progress"}
    local percentage=$((current * 100 / total))
    local filled=$((percentage * PROGRESS_WIDTH / 100))
    local empty=$((PROGRESS_WIDTH - filled))
    
    printf "\r%s: [%s%s] %d%%" "$prefix" \
        "$(printf '#%.0s' $(seq 1 $filled))" \
        "$(printf ' %.0s' $(seq 1 $empty))" \
        "$percentage"
}

confirm_action() {
    local prompt="$1"
    local default=${2:-"n"}
    
    while true; do
        printf "${YELLOW}%s [y/N]${NC} " "$prompt"
        read -r answer
        answer=${answer:-$default}
        case $answer in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

show_summary() {
    local succeeded=("$@")
    local failed=()
    local skipped=()
    
    echo -e "\n${WHITE}${BOLD}Operation Summary:${NC}"
    echo -e "${GREEN}Successfully processed:${NC} ${#succeeded[@]}"
    for item in "${succeeded[@]}"; do
        echo -e "  ✓ $item"
    done
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        echo -e "${RED}Failed operations:${NC} ${#failed[@]}"
        for item in "${failed[@]}"; do
            echo -e "  ✗ $item"
        done
    fi
    
    if [[ ${#skipped[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Skipped operations:${NC} ${#skipped[@]}"
        for item in "${skipped[@]}"; do
            echo -e "  - $item"
        done
    fi
}

show_interactive_menu() {
    clear
    echo -e "${WHITE}${BOLD}NTFS Drive Mounter - Interactive Mode${NC}\n"
    echo "Please select an operation:"
    echo -e "${CYAN}1)${NC} Mount all NTFS drives"
    echo -e "${CYAN}2)${NC} Mount specific drive"
    echo -e "${CYAN}3)${NC} Unmount drives"
    echo -e "${CYAN}4)${NC} Show mount status"
    echo -e "${CYAN}5)${NC} Verify filesystem"
    echo -e "${CYAN}6)${NC} Add to fstab"
    echo -e "${CYAN}7)${NC} Show help"
    echo -e "${CYAN}8)${NC} Force unmount stuck drives"
    echo -e "${CYAN}q)${NC} Quit\n"
    
    while true; do
        printf "Enter your choice: "
        read -r choice
        case $choice in
            1) return 1 ;;
            2) return 2 ;;
            3) return 3 ;;
            4) return 4 ;;
            5) return 5 ;;
            6) return 6 ;;
            7) return 7 ;;
            [Qq]) return 0 ;;
            *) echo "Invalid choice. Please try again." ;;
        esac
    done
}

format_mount_status() {
    echo -e "${WHITE}${BOLD}Current NTFS Mounts:${NC}"
    printf "%-20s %-15s %-10s %-25s\n" "DEVICE" "LABEL" "TYPE" "MOUNT POINT"
    printf "%s\n" "$(printf '=%.0s' $(seq 1 70))"
    
    while read -r line; do
        local device label mount_point
        device=$(echo "$line" | awk '{print $1}')
        label=$(blkid -s LABEL -o value "$device")
        local _type
        _type=$(echo "$line" | awk '{print $3}')
        mount_point=$(echo "$line" | awk '{print $2}')
        printf "%-20s %-15s %-10s %-25s\n" \
            "${device:0:20}" \
            "${label:0:15}" \
            "${_type:0:10}" \
            "${mount_point:0:25}"
    done < <(mount | grep -E "ntfs|ntfs-3g")
}

# Logging functions
rotate_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")
        if (( size > MAX_LOG_SIZE )); then
            for ((i=MAX_LOG_FILES-1; i>=1; i--)); do
                [[ -f "$LOG_FILE.$i" ]] && mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
            done
            mv "$LOG_FILE" "$LOG_FILE.1"
            touch "$LOG_FILE"
            chmod 644 "$LOG_FILE"
            chown "$SUDO_USER:$(id -g "$SUDO_USER")" "$LOG_FILE"
        fi
    fi
}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
        chown "$SUDO_USER:$(id -g "$SUDO_USER")" "$LOG_DIR"
    fi
    
    # Create log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
        chown "$SUDO_USER:$(id -g "$SUDO_USER")" "$LOG_FILE"
    fi
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    rotate_logs
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    log "ERROR" "$1"
}

success() {
    echo -e "${GREEN}$1${NC}"
    log "INFO" "$1"
}

warn() {
    echo -e "${YELLOW}Warning: $1${NC}"
    log "WARN" "$1"
}

info() {
    echo -e "${BLUE}Info: $1${NC}"
    log "INFO" "$1"
}

# Initialize logging
init_logging() {
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi
    
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi
    
    chown "$SUDO_USER:$(id -g "$SUDO_USER")" "$LOG_FILE"
    chmod 644 "$LOG_FILE"
}

# Function to show help message
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [DEVICE]

Automatically detects and mounts NTFS drives with advanced features.

Options:
-h, --help           Show this help message
-f, --fstab          Add entries to /etc/fstab for permanent mounting
--force              Force mount dirty volumes (use with caution)
--user USER          Specify username (defaults to current user)
--mountdir DIR       Specify base mount directory (defaults to /run/media/USERNAME)
--unmount            Unmount NTFS drives
--status            Show status of NTFS mounts
--device DEV        Filter status by device
--mountpoint DIR    Filter status by mount point
--verify            Verify NTFS filesystem integrity
--recover           Attempt to recover corrupted NTFS partition
--debug             Enable debug logging
--list             List all NTFS partitions

Examples:
$SCRIPT_NAME --force                # Mount all NTFS drives with force option
$SCRIPT_NAME -f                     # Mount and add to fstab
$SCRIPT_NAME --unmount /dev/sdb1    # Unmount specific NTFS drive
$SCRIPT_NAME --status               # Show mount status
$SCRIPT_NAME --verify /dev/sdb1     # Check filesystem integrity

Note: This script requires sudo privileges.
EOF
}

# Check if running with sudo
check_system_requirements() {
    local error_count=0
    
    # Check bash version
    if ((BASH_VERSINFO[0] < 4)); then
        error "Bash 4.0 or higher is required"
        ((error_count++))
    fi
    
    # Check if running on Linux
    if [[ $(uname -s) != "Linux" ]]; then
        error "This script requires a Linux-based operating system"
        ((error_count++))
    fi
    
    # Check for sudo privileges
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run with sudo privileges"
        ((error_count++))
    fi
    
    # Check system memory
    local mem_available
    mem_available=$(free -m | awk '/^Mem:/{print $7}')
    if ((mem_available < 100)); then
        warn "System is low on memory. This might affect performance."
    fi
    
    # Check disk space
    local disk_space
    disk_space=$(df -m / | awk 'NR==2 {print $4}')
    if ((disk_space < 100)); then
        warn "Low disk space on root partition. This might affect operation."
    fi
    
    if ((error_count > 0)); then
        error "System requirements check failed with $error_count error(s)"
        return 1
    fi
    
    success "System requirements check passed"
    return 0
}

# Check for required tools
check_dependencies() {
    local missing_deps=()
    
    for cmd in blkid mount ntfs-3g grep awk ntfsfix ntfsinfo; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing packages and try again."
        exit 1
    fi
}

# Check for hibernated Windows
check_hibernation() {
    local device="$1"
    local hibernate_status
    
    hibernate_status=$(ntfsinfo "$device" 2>/dev/null | grep -i "Hibernated:" || true)
    
    if [[ "$hibernate_status" == *"Yes"* ]]; then
        warn "Windows hibernation detected on $device"
        warn "Mounting in read-only mode to prevent data corruption"
        return 1
    fi
    return 0
}

# Verify NTFS filesystem
verify_filesystem() {
    local device="$1"
    
    info "Verifying filesystem on $device"
    if ntfsfix -d "$device"; then
        success "Filesystem verification completed successfully"
        return 0
    else
        error "Filesystem verification failed"
        return 1
    fi
}

# Get NTFS partitions
get_ntfs_partitions() {
    blkid | grep -i "type=\"ntfs\"" | cut -d: -f1
}

# Validate and sanitize filesystem paths
validate_path() {
    local path="$1"
    local description="$2"
    
    # Trim whitespace while preserving internal spaces
    path=$(echo "$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check for empty path
    if [[ -z "$path" ]]; then
        error "Empty $description is not allowed"
        return 1
    fi
    
    # Check for directory traversal attempts
    if [[ "$path" == *".."* ]]; then
        error "Directory traversal detected in $description"
        return 1
    fi
    
    # Replace truly unsafe characters while preserving most special chars
    path=$(echo "$path" | sed 's/[\/\0\x27\x22]/-/g')
    
    echo "$path"
    return 0
}

check_mount_point_accessibility() {
    local mount_point="$1"
    
    # Test directory creation
    if ! mkdir -p "$mount_point" 2>/dev/null; then
        error "Cannot create mount point: $mount_point"
        return 1
    fi
    
    # Test write permission
    if ! touch "$mount_point/.test_write" 2>/dev/null; then
        error "Cannot write to mount point: $mount_point"
        rmdir "$mount_point" 2>/dev/null
        return 1
    fi
    rm -f "$mount_point/.test_write"
    
    return 0
}

# Create mount point directory safely
create_mount_point() {
    local device="$1"
    local _="$2"
    local base_dir="$3"
    
    # Get label or use device name if no label
    local label
    label=$(blkid -o value -s LABEL "$device" 2>/dev/null || echo "${device##*/}")
    
    [[ "$debug_mode" == "true" ]] && info "Raw label: $label"
    
    # Validate and sanitize the label
    label=$(validate_path "$label" "device label") || return 1
    
    [[ "$debug_mode" == "true" ]] && info "Sanitized label: $label"
    
    # Validate label is not empty
    if [[ -z "$label" ]]; then
        error "Failed to get valid label for device: $device"
        return 1
    fi
    
    local mount_point="$base_dir/$label"
    
    # Create mount point if it doesn't exist
    if [[ ! -d "$mount_point" ]]; then
        if ! mkdir -p "$mount_point" 2>/dev/null; then
            error "Failed to create mount point: $mount_point"
            return 1
        fi
        
        # Verify directory was created
        if [[ ! -d "$mount_point" ]]; then
            error "Mount point was not created successfully: $mount_point"
            return 1
        fi
    fi
    
    # Set proper ownership and permissions
    if ! chown "$SUDO_USER:$(id -g "$SUDO_USER")" "$mount_point"; then
        error "Failed to set ownership of mount point: $mount_point"
        rmdir "$mount_point" 2>/dev/null  # Cleanup on failure
        return 1
    fi
    
    if ! chmod 755 "$mount_point"; then
        error "Failed to set permissions of mount point: $mount_point"
        rmdir "$mount_point" 2>/dev/null  # Cleanup on failure
        return 1
    fi
    
    # All operations successful
    success "Created mount point: $mount_point"
    echo "$mount_point"
    return 0
}

# Backup important files
create_backup() {
    local file="$1"
    local backup_file
    backup_file="$BACKUP_DIR/$(basename "$file").$(date +%Y%m%d-%H%M%S)"
    
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$backup_file"
    success "Created backup: $backup_file"
}

# Attempt to repair NTFS filesystem
repair_ntfs() {
    local device="$1"
    local repair_mode="$2"  # "check" or "repair"
    
    if [[ "$repair_mode" == "check" ]]; then
        if ! ntfsfix -n "$device" &>/dev/null; then
            return 1
        fi
    elif [[ "$repair_mode" == "repair" ]]; then
        info "Attempting to repair NTFS filesystem on $device"
        if ntfsfix -d "$device"; then
            success "Successfully repaired NTFS filesystem on $device"
            return 0
        else
            error "Failed to repair NTFS filesystem on $device"
            return 1
        fi
    fi
    return 0
}

# Mount NTFS partition
mount_partition() {
    local device="$1"
    local mount_point="$2"
    local force_mount="$3"
    
    [[ "$debug_mode" == "true" ]] && {
        info "Mounting device: $device"
        info "Mount point: $mount_point"
        info "Force mount: $force_mount"
    }
    
    # Validate mount point
    mount_point=$(validate_path "$mount_point" "mount point") || return 1
    
    # Check if already mounted anywhere
    if findmnt "$device" &>/dev/null; then
        warn "$device is already mounted"
        return 0
    fi

    # Test mount point accessibility
    if ! check_mount_point_accessibility "$mount_point"; then
        return 1
    fi

    [[ "$debug_mode" == "true" ]] && info "Mount point accessibility check passed"
    
    # Check for hibernation unless force mount is enabled
    if [[ "$force_mount" != "true" ]] && ! check_hibernation "$device"; then
        warn "Device $device is hibernated. Use --force to mount anyway"
        return 1
    fi
    
    local mount_options
    mount_options="uid=$(id -u "$SUDO_USER"),gid=$(id -g "$SUDO_USER"),$MOUNT_OPTIONS"
    
    if [[ "$force_mount" == "true" ]]; then
        mount_options+=",force"
    fi
    
    # Check filesystem health first
    if ! repair_ntfs "$device" "check"; then
        warn "NTFS filesystem on $device may need repair"
        if [[ "$force_mount" != "true" ]]; then
            info "Attempting automatic repair..."
            repair_ntfs "$device" "repair"
        fi
    fi
    
    local mount_output
    local mount_error
    
    # Try ntfs3 first (kernel driver)
    if mount_output=$(mount -t ntfs3 -o "$mount_options" "$device" "$mount_point" 2>&1); then
        success "Successfully mounted $device at $mount_point using ntfs3 driver"
        # Check for and execute ntfs-status.sh script
        if [[ -x "./ntfs-status.sh" ]]; then
            ./ntfs-status.sh "$device" "$mount_point" &
        elif [[ -x "/usr/local/bin/ntfs-status.sh" ]]; then
            /usr/local/bin/ntfs-status.sh "$device" "$mount_point" &
        fi
        return 0
    else
        mount_error="$mount_output"
        info "ntfs3 driver failed, trying ntfs-3g..."
    fi
    
    # Try ntfs-3g with basic options
    if mount_output=$(mount -t ntfs-3g -o "$mount_options" "$device" "$mount_point" 2>&1); then
        success "Successfully mounted $device at $mount_point using ntfs-3g"
        # Check for and execute ntfs-status.sh script
        if [[ -x "./ntfs-status.sh" ]]; then
            ./ntfs-status.sh "$device" "$mount_point" &
        elif [[ -x "/usr/local/bin/ntfs-status.sh" ]]; then
            /usr/local/bin/ntfs-status.sh "$device" "$mount_point" &
        fi
        return 0
    else
        mount_error="$mount_output"
    fi
    
    # If both attempts failed and force isn't enabled, try repair
    if [[ "$force_mount" != "true" ]]; then
        warn "Mount failed. Attempting filesystem repair..."
        if repair_ntfs "$device" "repair"; then
            # Try mounting one last time after repair
            if mount_output=$(mount -t ntfs-3g -o "$mount_options" "$device" "$mount_point" 2>&1); then
                success "Successfully mounted $device at $mount_point after repair"
                # Check for and execute ntfs-status.sh script
                if [[ -x "./ntfs-status.sh" ]]; then
                    ./ntfs-status.sh "$device" "$mount_point" &
                elif [[ -x "/usr/local/bin/ntfs-status.sh" ]]; then
                    /usr/local/bin/ntfs-status.sh "$device" "$mount_point" &
                fi
                return 0
            fi
        fi
    fi
    
    # If we get here, all mount attempts failed
    error "Failed to mount $device at $mount_point"
    error "Mount error: $mount_error"
    return 1
}

# Unmount NTFS partition
interactive_unmount() {
    local force=$1
    local mounted_partitions=()
    local i=1
    
    echo -e "\n${WHITE}${BOLD}Currently mounted NTFS partitions:${NC}"
    while read -r device mount_point _fs_type _; do
        local label size usage
        label=$(blkid -s LABEL -o value "$device" 2>/dev/null || echo "NO_LABEL")
        size=$(df -h "$device" | tail -n1 | awk '{print $2}')
        usage=$(df -h "$device" | tail -n1 | awk '{print $5}')
        mounted_partitions+=("$device:$mount_point")
        printf "%2d) %-15s %-30s (%s, used: %s)\n" "$i" "$label" "$mount_point" "$size" "$usage"
        ((i++))
    done < <(mount | grep -E "ntfs|ntfs-3g")
    
    if [[ ${#mounted_partitions[@]} -eq 0 ]]; then
        info "No mounted NTFS partitions found."
        return 0
    fi
    
    local selected
    while true; do
        echo -e "\nSelect partitions to unmount (comma-separated numbers, 'all' for all, or 'q' to quit):"
        read -r selected
        
        case $selected in
            [Qq]) return 0 ;;
            [Aa][Ll][Ll]) break ;;
            *[0-9]*)
                if [[ $selected =~ ^[0-9,[:space:]]+$ ]]; then
                    break
                else
                    error "Invalid input. Please use numbers separated by commas."
                fi
                ;;
            *) error "Invalid input. Please try again." ;;
        esac
    done
    
    local unmount_list=()
    if [[ $selected == "all" ]]; then
        unmount_list=("${mounted_partitions[@]}")
    else
        IFS=',' read -ra numbers <<< "$selected"
        for num in "${numbers[@]}"; do
            num=$(echo "$num" | tr -d '[:space:]')
            if (( num > 0 && num <= ${#mounted_partitions[@]} )); then
                unmount_list+=("${mounted_partitions[$((num-1))]}")
            fi
        done
    fi
    
    local total_unmounts=${#unmount_list[@]}
    local current=0
    local succeeded=()
    local failed=()
    
    for entry in "${unmount_list[@]}"; do
        IFS=':' read -r device mount_point <<< "$entry"
        ((current++))
        progress_bar "$current" "$total_unmounts" "Unmounting"
        
        if unmount_partition "$mount_point" "$force"; then
            succeeded+=("$mount_point")
        else
            failed+=("$mount_point")
        fi
    done
    
    echo -e "\n${GREEN}Successfully unmounted: ${#succeeded[@]}${NC}"
    echo -e "${RED}Failed to unmount: ${#failed[@]}${NC}"
    
    if [[ ${#failed[@]} -gt 0 && $force != "true" ]]; then
        if confirm_action "Would you like to force unmount the failed partitions?"; then
            for mount_point in "${failed[@]}"; do
                if unmount_partition "$mount_point" "true"; then
                    succeeded+=("$mount_point")
                    failed=("${failed[@]/$mount_point}")
                fi
            done
        fi
    fi
    
    show_summary "${succeeded[@]}" "${failed[@]}"
}

unmount_partition() {
    local mount_point="$1"
    local force="$2"
    
    if ! mountpoint -q "$mount_point"; then
        warn "$mount_point is not mounted"
        return 0
    fi
    
    # Check if the mount point is busy
    local lsof_check
    if lsof_check=$(lsof "$mount_point" 2>/dev/null); then
        warn "Mount point $mount_point is busy:"
        echo "$lsof_check"
        if [[ "$force" != "true" ]]; then
            error "Unmount aborted. Use force option to override."
            return 1
        fi
    fi
    
    # Check for disk activity
    local device
    device=$(df "$mount_point" | tail -n1 | awk '{print $1}')
    if [[ -n "$device" ]]; then
        local disk_activity
        disk_activity=$(iostat -d -x 1 2 "$device" 2>/dev/null | tail -n2 | head -n1 | awk '{print $10}')
        if [[ -n "$disk_activity" && "$disk_activity" != "0.00" && "$force" != "true" ]]; then
            warn "Disk activity detected on $mount_point"
            if ! confirm_action "Continue unmounting despite disk activity?"; then
                return 1
            fi
        fi
    fi
    
    spinner_start "Unmounting $mount_point"
    local umount_cmd="umount"
    [[ "$force" == "true" ]] && umount_cmd="umount -f"
    
    if $umount_cmd "$mount_point" 2>/dev/null; then
        spinner_stop
        success "Successfully unmounted $mount_point"
        
        # Cleanup empty mount point if it's under /run/media
        if [[ "$mount_point" =~ ^/run/media/ && -d "$mount_point" ]]; then
            rmdir "$mount_point" 2>/dev/null
        fi
        return 0
    else
        spinner_stop
        error "Failed to unmount $mount_point"
        return 1
    fi
}
# Show mount status
show_mount_status() {
    local device="$1"
    local mount_point="$2"
    
    local filter_cmd="mount | grep -E 'ntfs|ntfs-3g'"
    
    if [[ -n "$device" ]]; then
        filter_cmd="$filter_cmd | grep -E $(printf %q "$device")"
    fi
    if [[ -n "$mount_point" ]]; then
        filter_cmd="$filter_cmd | grep -E $(printf %q "$mount_point")"
    fi
    
    if ! eval "$filter_cmd" > /dev/null; then
        if [[ -n "$device" || -n "$mount_point" ]]; then
            echo -e "\n${YELLOW}No matching NTFS partitions mounted${NC}\n"
        else
            echo -e "\n${YELLOW}No NTFS partitions currently mounted${NC}\n"
        fi
        return
    fi
    
    echo -e "${WHITE}${BOLD}Current NTFS Mounts:${NC}"
    printf "%-20s %-15s %-10s %-25s\n" "DEVICE" "LABEL" "TYPE" "MOUNT POINT"
    printf "%s\n" "$(printf '=%.0s' $(seq 1 70))"
    
    while read -r line; do
        local device_info mount_point_info fs_type
        device_info=$(echo "$line" | awk '{print $1}')
        mount_point_info=$(echo "$line" | awk '{print $2}')
        fs_type=$(echo "$line" | awk '{print $3}')
        local label
        label=$(blkid -s LABEL -o value "$device_info")
        
        printf "%-20s %-15s %-10s %-25s\n" \
            "${device_info:0:20}" \
            "${label:0:15}" \
            "${fs_type:0:10}" \
            "${mount_point_info:0:25}"
    done < <(eval "$filter_cmd")
}

# Add entry to fstab
add_to_fstab() {
    local device="$1"
    local mount_point="$2"
    
    # Validate and sanitize mount point for fstab
    mount_point=$(validate_path "$mount_point" "fstab mount point") || return 1
    
    [[ "$debug_mode" == "true" ]] && info "Adding to fstab - Device: $device, Mount point: $mount_point"
    local uuid
    uuid=$(blkid -s UUID -o value "$device")
    
    if [[ -z "$uuid" ]]; then
        error "Could not get UUID for device $device"
        return 1
    fi
    
    local fstab_line
    fstab_line="UUID=$uuid $mount_point ntfs-3g $MOUNT_OPTIONS,uid=$(id -u "$SUDO_USER"),gid=$(id -g "$SUDO_USER") 0 0"
    
    # Check if entry already exists
    if grep -q "$mount_point" /etc/fstab; then
        warn "Mount point $mount_point already exists in fstab"
        return 0
    fi
    
    # Backup fstab
    create_backup "/etc/fstab"
    
    echo "$fstab_line" >> /etc/fstab
    success "Added entry to fstab for $device"
}

main() {
    local add_to_fstab=false
    local force_mount=false
    local custom_user=""
    local mount_base_dir=""
    local unmount_mode=false
    local show_status=false
    local verify_mode=false
    local debug_mode=false
    local specific_device=""
    local specific_mount_point=""
    local interactive_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--fstab)
                add_to_fstab=true
                shift
                ;;
            --force)
                force_mount=true
                shift
                ;;
            --user)
                custom_user="$2"
                shift 2
                ;;
            --mountdir)
                mount_base_dir="$2"
                shift 2
                ;;
            --unmount)
                unmount_mode=true
                [[ $# -gt 1 ]] && specific_device="$2"
                shift
                ;;
            --status)
                show_status=true
                shift
                ;; 
            --device)
                specific_device="$2"
                shift 2
                ;;
            --mountpoint)
                specific_mount_point="$2"
                shift 2
                ;;
            --verify)
                verify_mode=true
                [[ $# -gt 1 ]] && specific_device="$2"
                shift
                ;;
            --debug)
                debug_mode=true
                if [[ "$debug_mode" == "true" ]]; then
                    set -x
                fi
                shift
                ;;
            -i|--interactive)
                interactive_mode=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verify root privileges
    check_sudo
    
    # Initialize logging
    init_logging
    
    # Check dependencies
    check_dependencies
    
    # Set user and mount base directory
    SUDO_USER=${custom_user:-${SUDO_USER:-$(whoami)}}
    mount_base_dir=${mount_base_dir:-"/run/media/$SUDO_USER"}

    if [[ "$interactive_mode" == "true" ]]; then
        while true; do
            show_interactive_menu
            local menu_choice=$?
            case $menu_choice in
                0) exit 0 ;;
                1) ;;  # Mount all - continue with default behavior
                2)
                    echo "Available NTFS drives:"
                    local i=1
                    local devices=()
                    while read -r device; do
                        label=$(blkid -s LABEL -o value "$device")
                        echo "$i) $device ($label)"
                        devices+=("$device")
                        ((i++))
                    done < <(get_ntfs_partitions)
                    
                    read -rp "Select drive number: " drive_num
                    if [[ $drive_num -ge 1 && $drive_num -le ${#devices[@]} ]]; then
                        specific_device="${devices[$((drive_num-1))]}"
                    else
                        error "Invalid selection"
                        continue
                    fi
                    ;;
                3) interactive_unmount false; continue ;;
                4) show_mount_status; continue ;;
                5) verify_mode=true ;;
                6) add_to_fstab=true ;;
                7) show_help; continue ;;
                8) interactive_unmount true; continue ;;
            esac
        done
    fi

    # Handle different operation modes
    if [[ "$show_status" == "true" ]]; then
        show_mount_status "$specific_device" "$specific_mount_point"
        exit 0
    fi
    
    if [[ "$verify_mode" == "true" ]]; then
        if [[ -n "$specific_device" ]]; then
            verify_filesystem "$specific_device"
        else
            error "Please specify a device to verify"
            exit 1
        fi
        exit 0
    fi
    
    # Get NTFS partitions
    local partitions
    if [[ -n "$specific_device" ]]; then
        partitions=("$specific_device")
    else
        mapfile -t partitions < <(get_ntfs_partitions)
    fi
    
    if [[ ${#partitions[@]} -eq 0 ]]; then
        error "No NTFS partitions found"
        exit 1
    fi
    
    success "Found ${#partitions[@]} NTFS partition(s)"
    
    # Process each partition
    for device in "${partitions[@]}"; do
        local mount_point
        mount_point=$(create_mount_point "$device" "$(basename "$device")" "$mount_base_dir")
        
        if [[ "$unmount_mode" == "true" ]]; then
            unmount_partition "$mount_point"
        else
            if mount_partition "$device" "$mount_point" "$force_mount"; then
                # Check for and execute ntfs-status.sh script
                if [[ -x "./ntfs-status.sh" ]]; then
                    ./ntfs-status.sh "$device" "$mount_point" &
                elif [[ -x "/usr/local/bin/ntfs-status.sh" ]]; then
                    /usr/local/bin/ntfs-status.sh "$device" "$mount_point" &
                fi
                
                if [[ "$add_to_fstab" == "true" ]]; then
                    add_to_fstab "$device" "$mount_point"
                fi
            fi
        fi
    done
}

# Signal handling and cleanup
cleanup() {
    local exit_code=$?
    info "Cleaning up and performing final operations..."
    
    # Remove temporary files
    rm -f /tmp/spinner.pid
    
    # Reset terminal
    [[ -t 1 ]] && tput cnorm  # show cursor only if output is terminal
    [[ -t 0 ]] && stty echo   # restore echo only if input is terminal
    
    # Final log entry
    log "INFO" "Script completed with exit code $exit_code"
    
    # Rotate logs on exit if needed
    rotate_logs
    
    exit $exit_code
}

# Set up signal handling
trap cleanup EXIT
trap 'echo; error "Operation cancelled by user"; exit 1' INT TERM

# Version check function
version_check() {
    local required_version="$1"
    local current_version="$2"
    local package="$3"
    
    if ! command -v "$package" &>/dev/null; then
        error "$package is required but not installed"
        return 1
    fi
    
    if [[ "$package" == "ntfs-3g" ]]; then
        current_version=$(ntfs-3g --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
    fi
    
    if [[ $(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1) != "$required_version" ]]; then
        error "$package version $required_version or higher is required (current: $current_version)"
        return 1
    fi
    
    return 0
}

# Check if running with sudo privileges
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run with sudo privileges"
        return 1
    fi
    return 0
}

# Run main program with requirement checks
if check_system_requirements && version_check "2021.8.22" "$(ntfs-3g --version 2>&1)" "ntfs-3g"; then
    main "$@"
else
    error "Pre-run checks failed. Please review the requirements and try again."
    exit 1
fi
