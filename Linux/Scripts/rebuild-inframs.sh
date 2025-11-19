#!/usr/bin/env bash
# =============================================================
# NVIDIA Gaming Setup v2.4 - Embedded DKMS + Thorough Initramfs + Keyring Fix + Conflict Handling + Verbose/Progress
# Author: DuckyOnQuack-999 (merged & hardened) + Grok enhancements
# Purpose: Install NVIDIA drivers (handle conflicts), rebuild DKMS across kernels,
#          rebuild initramfs for all kernels with backup/rollback,
#          fix common pacman keyring issues, log actions and provide colored/progress output.
# =============================================================
# Wrapper Addition: Mount + Chroot for LiveCD Repair
# If run on live CD, choose to auto-mount/chroot or run directly.
# When chrooted, auto-selects livecd mode.

set -euo pipefail
IFS=$'\n\t'

LOGFILE="/var/log/initramfs-rebuild.log"
TIMESTAMP() { date +"%F %T"; }

# -------------------------
# Basic helpers: logging & colors
# -------------------------
# Colors (fallback to ANSI if tput not available)
if command -v tput &>/dev/null; then
    RED="$(tput setaf 1)"
    GRN="$(tput setaf 2)"
    YLW="$(tput setaf 3)"
    BLU="$(tput setaf 4)"
    BOLD="$(tput bold)"
    RST="$(tput sgr0)"
else
    RED="\e[31m"
    GRN="\e[32m"
    YLW="\e[33m"
    BLU="\e[34m"
    BOLD="\e[1m"
    RST="\e[0m"
fi

log() {
    echo -e "${BOLD}[$(TIMESTAMP)]${RST} $*" | tee -a "$LOGFILE"
}
info() {
    echo -e "${GRN}[INFO]${RST} $*"
    log "[INFO] $*"
}
warn() {
    echo -e "${YLW}[WARN]${RST} $*"
    log "[WARN] $*"
}
err() {
    echo -e "${RED}[ERROR]${RST} $*"
    log "[ERROR] $*"
}

progress_spinner_start() {
    # call spinner_stop to stop
    SPINNER_PID=""
    (
        i=0
        chars=("| " "/" "-" "\\")
        while true; do
            printf "\r%s " "${chars[i++ % ${#chars[@]}]}"
            sleep 0.12
        done
    ) &
    SPINNER_PID=$!
    disown
}
progress_spinner_stop() {
    if [ -n "${SPINNER_PID:-}" ]; then
        kill "$SPINNER_PID" &>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        unset SPINNER_PID
        printf "\r"
    fi
}

# Simple progress bar for multi-step processes
progress_bar() {
    local current=$1 total=$2 label="$3"
    local percent=$((current * 100 / total))
    local bar=$(printf "=%.0s" $(seq 1 $((percent / 2))))
    printf "\r${YLW}[%s] %d%% %s${RST}" "$bar$(printf ' %.0s' $(seq 1 $((50 - ${#bar}))))" "$percent" "$label"
    [ $current -eq $total ] && echo ""  # Newline on complete
}

# Ensure logfile exists
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
chmod 640 "$LOGFILE" || true

# -------------------------
# Early root check (needed for wrapper mounts)
# -------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)." >&2
    exit 1
fi

# -------------------------
# Wrapper Logic: Mount + Chroot Option
# -------------------------
CHROOTED=""
if [ $# -gt 0 ] && [ "$1" = "--chrooted" ]; then
    CHROOTED=1
    shift
fi

if [ -z "$CHROOTED" ]; then
    echo -e "\n${BLU}NVIDIA Gaming Setup v2.4 - LiveCD Repair Ready${RST}"
    echo "Detected potential live environment. Do you want to use the mount + chroot wrapper?"
    echo " - Yes: Auto-mount your install root, bind mounts, chroot, and run in repair mode."
    echo " - No: Run directly (use if already chrooted or on native system)."
    while true; do
        read -p "Use wrapper? (y/n): " USE_WRAPPER
        case "${USE_WRAPPER,,}" in
            y|yes)
                info "Using mount + chroot wrapper."
                break
                ;;
            n|no)
                info "Running without wrapper."
                USE_WRAPPER=""
                break
                ;;
            *)
                warn "Please enter y or n."
                ;;
        esac
    done

    if [ -n "$USE_WRAPPER" ]; then
        # Prompt for root device
        echo -e "\n${YLW}Enter your root partition (e.g., /dev/sda2). Use 'lsblk' to list devices if needed.${RST}"
        read -p "Root device: " ROOT_DEV
        if [ -z "$ROOT_DEV" ] || ! blkid "$ROOT_DEV" &>/dev/null; then
            err "Invalid root device. Exiting."
            exit 1
        fi

        # Unmount /mnt if already mounted
        info "Unmounting /mnt if necessary..."
        umount /mnt/* 2>/dev/null || true
        umount /mnt 2>/dev/null || true

        # Mount root
        info "Mounting $ROOT_DEV to /mnt..."
        mount "$ROOT_DEV" /mnt || { err "Failed to mount $ROOT_DEV"; exit 1; }

        # Prompt for separate /boot
        echo -e "\n${YLW}Is /boot on a separate partition? (e.g., /dev/sda1)${RST}"
        read -p "Separate /boot? (y/n): " BOOT_SEP
        if [[ "${BOOT_SEP,,}" == "y" ]]; then
            read -p "Boot device: " BOOT_DEV
            if [ -n "$BOOT_DEV" ]; then
                info "Mounting $BOOT_DEV to /mnt/boot..."
                mount "$BOOT_DEV" /mnt/boot || warn "Failed to mount boot; proceeding without."
            fi
        fi

        # Bind mounts
        info "Setting up bind mounts..."
        mount --bind /dev /mnt/dev || warn "Failed to bind /dev"
        mount --bind /proc /mnt/proc || warn "Failed to bind /proc"
        mount --bind /sys /mnt/sys || warn "Failed to bind /sys"
        mount --bind /run /mnt/run || warn "Failed to bind /run"
        mount --bind /dev/pts /mnt/dev/pts || warn "Failed to bind /dev/pts"

        # Copy script to chroot
        SCRIPT_IN_CHROOT="/tmp/nvidia_setup.sh"
        cp "$0" "/mnt$SCRIPT_IN_CHROOT" || { err "Failed to copy script to chroot"; exit 1; }
        info "Entering chroot and running script in repair mode..."
        # Exec into chroot with the script
        exec chroot /mnt /bin/bash "${SCRIPT_IN_CHROOT}" --chrooted || { err "Chroot exec failed"; exit 1; }
    fi
fi

# -------------------------
# Keyring fix for common Arch signature issues (e.g., Bert Peters key)
# -------------------------
fix_keyring() {
    info "Detected keyring issue. Fixing pacman keyring (common 2025 signature trust issues)..."

    # Sync time if possible (invalidates old sigs)
    if command -v timedatectl &>/dev/null; then
        info "Syncing NTP for valid signatures..."
        timedatectl set-ntp true &>>"$LOGFILE" || warn "NTP sync failed; check time manually."
    fi

    # Clear common corrupted caches (e.g., lib32-libldap, sane, protobuf from 2025 reports)
    CORRUPTED_PKGS=("lib32-libldap" "sane" "protobuf")
    info "Clearing potentially corrupted package caches..."
    cleared=0
    for pkg in "${CORRUPTED_PKGS[@]}"; do
        for f in /var/cache/pacman/pkg/"${pkg}"*-x86_64.pkg.tar.zst; do
            [ -f "$f" ] && rm -v "$f" &>>"$LOGFILE" && { info "Cleared ${pkg} cache: $f"; cleared=$((cleared+1)); }
        done
    done
    [ $cleared -eq 0 ] && info "No corrupted caches found."

    # Init and populate keys
    if command -v pacman-key &>/dev/null; then
        info "Initializing and populating pacman keys..."
        progress_spinner_start
        pacman-key --init &>>"$LOGFILE"
        pacman-key --populate archlinux &>>"$LOGFILE"
        if timeout 30 pacman-key --refresh-keys &>>"$LOGFILE"; then
            info "Key refresh completed."
        else
            warn "Key refresh timed out or had network issues; try manual import below."
        fi
        progress_spinner_stop

        # Manual import for Bert Peters if needed (fingerprint 2703040C)
        if ! pacman-key --list-keys 2703040C &>>"$LOGFILE" 2>&1 | grep -q "Bert Peters"; then
            info "Importing Bert Peters packager key (common 2025 issue)..."
            if timeout 30 pacman-key --recv-keys 2703040C &>>"$LOGFILE" && timeout 30 pacman-key --lsign-key 2703040C &>>"$LOGFILE"; then
                info "Bert Peters key imported and signed."
            else
                warn "Failed to import Bert Peters key; manual intervention needed."
            fi
        else
            info "Bert Peters key already present."
        fi
    else
        warn "pacman-key not available; skipping keyring fix."
    fi

    # Upgrade keyring package (with timeout)
    if command -v pacman &>/dev/null; then
        info "Upgrading archlinux-keyring package..."
        progress_spinner_start
        if timeout 60 pacman -Syy --noconfirm archlinux-keyring &>>"$LOGFILE"; then
            progress_spinner_stop
            info "Keyring package updated."
        else
            progress_spinner_stop
            warn "archlinux-keyring upgrade failed/timed out; try --skipinteg manually."
        fi
    fi
}

# -------------------------
# Mode selection dialog (skipped if CHROOTED)
# -------------------------
select_mode() {
    info "Welcome to NVIDIA Gaming Setup v2.4"
    echo -e "${BLU}Please select execution mode:${RST}"
    echo "1) Default: Run on native system (booted into target OS)"
    echo "2) LiveCD: Repair mode (must already be chrooted into target install)"
    echo -e "${YLW}Note: For LiveCD, ensure you've mounted /mnt, chrooted with 'arch-chroot /mnt', and exited to run this.${RST}"

    while true; do
        read -p "Enter choice (1 or 2): " MODE_CHOICE
        case $MODE_CHOICE in
            1)
                MODE="default"
                info "Selected: Default mode (native)."
                log "Execution mode: default"
                return 0
                ;;
            2)
                MODE="livecd"
                info "Selected: LiveCD repair mode."
                log "Execution mode: livecd"

                # Quick chroot verification (heuristic: check for /run/archiso or prompt)
                if [ -d "/run/archiso" ]; then
                    warn "Detected potential live environment. Ensure you're chrooted into your install before proceeding."
                fi
                read -p "Confirm chrooted into target Arch install? (y/n): " CONFIRM
                if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
                    err "LiveCD mode requires chroot. Exiting."
                    exit 1
                fi
                return 0
                ;;
            *)
                warn "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# -------------------------
# Distro detection
# -------------------------
detect_distro() {
    if command -v pacman &>/dev/null; then
        DISTRO="arch"
    elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        DISTRO="fedora"
    elif command -v apt &>/dev/null; then
        DISTRO="debian"
    elif command -v zypper &>/dev/null; then
        DISTRO="suse"
    else
        DISTRO="unknown"
    fi
    info "Detected distro: $DISTRO"
}

# -------------------------
# Install NVIDIA drivers (simple, distro-adaptive) + Conflict Handling + Verbose/Progress
# Modify this section to match your repo choices (dkms vs packaged).
# -------------------------
install_nvidia_drivers() {
    info "Installing NVIDIA drivers and recommended packages for $DISTRO..."
    case "$DISTRO" in
    arch)
        # Step 1: Sync and upgrade with conditional keyring fix + progress
        info "Step 1/3: Syncing repositories and upgrading system..."
        progress_bar 1 3 "Syncing..."
        if ! output=$(timeout 60 pacman -Syu --noconfirm 2>&1); then
            log "Pacman -Syu output: $output"
            if echo "$output" | grep -qiE "(unknown trust|invalid signature|corrupted package|Bert Peters)"; then
                warn "Detected keyring/signature error in pacman output."
                fix_keyring
                # Retry sync/upgrade
                info "Retrying sync/upgrade after keyring fix..."
                progress_bar 1 3 "Retrying sync..."
                if timeout 60 pacman -Syu --noconfirm &>>"$LOGFILE"; then
                    info "Retry succeeded after keyring fix."
                else
                    err "Retry failed after keyring fix. Check $LOGFILE."
                    return 1
                fi
            else
                err "Pacman sync/upgrade failed (non-key issue)."
                return 1
            fi
        else
            info "System sync/upgrade completed."
        fi
        progress_bar 2 3 "Sync complete."

        # Step 2: Handle conflict: Remove precompiled nvidia if installed
        info "Step 2/3: Checking for conflicting packages..."
        progress_bar 2 3 "Checking conflicts..."
        if pacman -Q nvidia &>/dev/null; then
            info "Detected conflicting 'nvidia' package. Removing it to install DKMS version..."
            progress_spinner_start
            if pacman -Rns --noconfirm nvidia &>>"$LOGFILE"; then
                progress_spinner_stop
                info "Conflicting 'nvidia' package removed successfully."
            else
                progress_spinner_stop
                warn "Failed to remove nvidia; manual removal may be needed. Output logged."
            fi
        else
            info "No conflicting 'nvidia' package found."
        fi
        progress_bar 3 3 "Conflicts resolved."

        # Step 3: Install DKMS version (prefer for multi-kernel support)
        info "Step 3/3: Installing NVIDIA DKMS and dependencies..."
        progress_bar 3 3 "Installing packages..."
        if ! pacman -Q nvidia-dkms &>/dev/null; then
            progress_spinner_start
            if pacman -S --noconfirm --needed dkms nvidia-dkms nvidia-utils nvidia-settings \
                vulkan-icd-loader lib32-vulkan-icd-loader lib32-nvidia-utils &>>"$LOGFILE"; then
                progress_spinner_stop
                info "NVIDIA DKMS and dependencies installed successfully."
            else
                progress_spinner_stop
                warn "Package install had issues; see $LOGFILE for details."
            fi
        else
            info "nvidia-dkms already installed; skipping."
        fi
        progress_bar 3 3 "Installation complete."
        ;;
    fedora)
        info "Updating system and installing NVIDIA packages..."
        progress_spinner_start
        dnf -y update || { progress_spinner_stop; warn "DNF update failed"; }
        dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda vulkan vulkan-tools || { progress_spinner_stop; warn "DNF install failed"; }
        progress_spinner_stop
        info "Fedora NVIDIA install complete."
        ;;
    debian)
        info "Updating system and installing NVIDIA packages..."
        progress_spinner_start
        apt update || { progress_spinner_stop; warn "APT update failed"; }
        apt install -y dkms build-essential linux-headers-$(uname -r) nvidia-driver nvidia-settings vulkan-tools || { progress_spinner_stop; warn "APT install failed"; }
        progress_spinner_stop
        info "Debian NVIDIA install complete."
        ;;
    suse)
        info "Refreshing repos and installing NVIDIA packages..."
        progress_spinner_start
        zypper refresh || { progress_spinner_stop; warn "Zypper refresh failed"; }
        zypper install -y dkms kernel-devel x11-video-nvidiaG06 nvidia-computeG06 vulkan-tools || { progress_spinner_stop; warn "Zypper install failed"; }
        progress_spinner_stop
        info "SUSE NVIDIA install complete."
        ;;
    *)
        warn "Unsupported distro: $DISTRO. Manual install required."
        return 1
        ;;
    esac
    info "Driver install step complete."
}

# -------------------------
# Create pacman hook for auto DKMS/mkinitcpio on NVIDIA updates
# -------------------------
create_nvidia_hook() {
    HOOK_DIR="/etc/pacman.d/hooks"
    HOOK_FILE="$HOOK_DIR/nvidia.hook"
    if [ ! -f "$HOOK_FILE" ]; then
        info "Creating pacman hook for auto NVIDIA DKMS/mkinitcpio updates..."
        mkdir -p "$HOOK_DIR"
        cat > "$HOOK_FILE" << EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = nvidia-dkms
Target = linux-*

[Action]
Description = Rebuilding NVIDIA DKMS and initramfs
When = PostTransaction
Depends = dkms
Exec = /usr/bin/dkms autoinstall --verbose
Exec = /usr/bin/mkinitcpio -P
EOF
        info "Hook created at $HOOK_FILE."
    else
        info "Pacman hook already exists; skipping."
    fi
}

# -------------------------
# DKMS rebuild for NVIDIA across all kernels + Verification + Verbose
# -------------------------
rebuild_nvidia_dkms_modules() {
    info "Ensuring kernel headers + DKMS are available and rebuilding NVIDIA modules for all kernels."

    case "$DISTRO" in
    arch)
        # Install common headers if missing. --needed prevents reinstallation.
        info "Installing kernel headers for multi-kernel support..."
        progress_spinner_start
        pacman -S --noconfirm --needed linux-headers linux-lts-headers linux-zen-headers linux-hardened-headers &>>"$LOGFILE" || warn "Header install had issues"
        pacman -S --noconfirm --needed dkms nvidia-dkms &>>"$LOGFILE" || warn "DKMS install had issues"
        progress_spinner_stop

        # Create pacman hook
        create_nvidia_hook
        ;;
    debian)
        info "Installing DKMS for Debian..."
        progress_spinner_start
        apt install -y --no-install-recommends dkms &>>"$LOGFILE" || warn "DKMS install had issues"
        progress_spinner_stop
        ;;
    fedora | suse)
        # Assume akmod handles rebuilds; but keep dkms if present
        info "Assuming akmod/DKMS already handled for $DISTRO."
        ;;
    esac

    if ! command -v dkms &>/dev/null; then
        warn "DKMS not installed or not available. Attempting best-effort module build (may fail)."
        return 1
    fi

    info "Running dkms autoinstall (may take a while)..."
    progress_spinner_start
    if timeout 300 dkms autoinstall &>>"$LOGFILE"; then
        progress_spinner_stop
        info "DKMS autoinstall completed successfully."
    else
        progress_spinner_stop
        warn "DKMS autoinstall returned non-zero. Check $LOGFILE for details."
        # Attempt manual install for nvidia module if present
        if dkms status | grep -qi nvidia; then
            info "Attempting manual DKMS install for NVIDIA module..."
            dkms status | tee -a "$LOGFILE"
            # Get kernels and attempt per-kernel install
            mapfile -t KERNELS < <(ls -1 /lib/modules 2>/dev/null || true)
            for i in "${!KERNELS[@]}"; do
                k="${KERNELS[$i]}"
                info "Checking kernel ${i+1}/${#KERNELS[@]}: $k"
                nvidia_ver=$(pacman -Q nvidia-dkms 2>/dev/null | cut -d' ' -f1 | cut -d- -f3 || echo "latest")
                if ! dkms status "nvidia/$nvidia_ver/$k" | grep -q "installed"; then
                    info "Building NVIDIA for $k..."
                    timeout 120 dkms install "nvidia/$nvidia_ver" -k "$k" &>>"$LOGFILE" || warn "Manual DKMS install failed for $k"
                else
                    info "NVIDIA already installed for $k."
                fi
            done
        fi
    fi

    # Verify modules built
    info "Verifying NVIDIA DKMS modules built..."
    mapfile -t KERNELS < <(ls -1 /lib/modules 2>/dev/null || true)
    for i in "${!KERNELS[@]}"; do
        k="${KERNELS[$i]}"
        info "Kernel ${i+1}/${#KERNELS[@]}: $k"
        if [ -f "/lib/modules/$k/updates/dkms/nvidia.ko.xz" ]; then
            info "  -> NVIDIA module verified."
        else
            warn "  -> NVIDIA module missing; initramfs may fail for $k."
        fi
    done

    # For distros that use akmods (Fedora), attempt akmods --force
    if command -v akmods &>/dev/null; then
        info "Running akmods --force (if available)..."
        progress_spinner_start
        akmods --force &>>"$LOGFILE" || warn "akmods reported issues; see $LOGFILE"
        progress_spinner_stop
    fi
}

# -------------------------
# Initramfs rebuild: backup, rebuild per kernel (skip if no NVIDIA module), verify, rollback if needed + Verbose
# -------------------------
rebuild_initramfs_thorough() {
    info "Starting thorough initramfs rebuild."

    # Ensure mkinitcpio.conf includes nvidia if needed
    MKINITCONF="/etc/mkinitcpio.conf"
    if command -v mkinitcpio &>/dev/null && ! grep -q "nvidia" "$MKINITCONF"; then
        warn "Adding nvidia to mkinitcpio.conf MODULES for early loading..."
        sed -i '/^MODULES=/ s/()/ (nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCONF" &>>"$LOGFILE"
        info "mkinitcpio.conf updated."
    fi

    # Select initramfs engine
    INIT_TOOL=""
    if command -v mkinitcpio &>/dev/null; then INIT_TOOL="mkinitcpio"; fi
    if command -v dracut &>/dev/null; then INIT_TOOL="dracut"; fi
    if command -v update-initramfs &>/dev/null; then INIT_TOOL="update-initramfs"; fi

    if [ -z "$INIT_TOOL" ]; then
        err "No supported initramfs tool found (mkinitcpio/dracut/update-initramfs). Aborting."
        return 1
    fi
    info "Using initramfs tool: $INIT_TOOL"

    # Gather kernels from /lib/modules
    mapfile -t KERNELS < <(ls -1 /lib/modules 2>/dev/null || true)
    if [ "${#KERNELS[@]}" -eq 0 ]; then
        err "No kernels present in /lib/modules. Aborting."
        return 1
    fi
    info "Kernels detected: ${KERNELS[*]}"

    BACKUP_DIR="/tmp/initramfs_backup_$(date +%s)"
    mkdir -p "$BACKUP_DIR"
    info "Backing up current initramfs files to $BACKUP_DIR"
    find /boot -maxdepth 1 -type f -name "initramfs*" -exec cp -v {} "$BACKUP_DIR"/ \; 2>/dev/null | tee -a "$LOGFILE" || warn "Backup had issues"

    # Perform per-kernel rebuild and track failures (skip if no NVIDIA module)
    FAILURES=()
    for i in "${!KERNELS[@]}"; do
        k="${KERNELS[$i]}"
        info "Processing kernel ${i+1}/${#KERNELS[@]}: $k"
        if [ ! -f "/lib/modules/$k/updates/dkms/nvidia.ko.xz" ]; then
            warn "Skipping initramfs for $k: NVIDIA module not built."
            continue
        fi
        info "Rebuilding initramfs for kernel: $k"
        case "$INIT_TOOL" in
        mkinitcpio)
            OUT="/boot/initramfs-$k.img"
            progress_spinner_start
            output=$(mkinitcpio -k "$k" -g "$OUT" 2>&1 | tee -a "$LOGFILE")
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                progress_spinner_stop
                info "mkinitcpio succeeded for $k -> $OUT"
                echo "$output" | tail -1 | grep -v "^==>" | head -1 | sed 's/^/  Output: /'  # Verbose last line
            else
                progress_spinner_stop
                warn "mkinitcpio reported errors for $k (see $LOGFILE). Recording failure."
                echo "$output" | tail -3 | sed 's/^/  Error: /'  # Verbose last errors
                FAILURES+=("$k")
            fi
            ;;
        dracut)
            OUT="/boot/initramfs-$k.img"
            progress_spinner_start
            if dracut --force "$OUT" "$k" &>>"$LOGFILE"; then
                progress_spinner_stop
                info "dracut succeeded for $k -> $OUT"
            else
                progress_spinner_stop
                warn "dracut failed for $k. Recording failure."
                FAILURES+=("$k")
            fi
            ;;
        update-initramfs)
            progress_spinner_start
            if update-initramfs -c -k "$k" &>>"$LOGFILE"; then
                progress_spinner_stop
                info "update-initramfs succeeded for kernel $k"
            else
                progress_spinner_stop
                warn "update-initramfs failed for $k. Recording failure."
                FAILURES+=("$k")
            fi
            ;;
        esac
    done

    # Run depmod for consistency
    info "Running depmod for installed kernels..."
    for i in "${!KERNELS[@]}"; do
        k="${KERNELS[$i]}"
        info "depmod for kernel ${i+1}/${#KERNELS[@]}: $k"
        depmod "$k" &>>"$LOGFILE" || warn "depmod failed for $k (see $LOGFILE)"
    done

    # Verify images exist and are not empty
    WARNED=0
    info "Verifying initramfs images..."
    for f in /boot/initramfs-*; do
        [ -e "$f" ] || continue
        if [ ! -s "$f" ]; then
            warn "Initramfs file $f is empty or zero size. Marking as failure."
            WARNED=1
        else
            info "Verified: $f ($(du -h "$f" | cut -f1))"
        fi
    done

    if [ "${#FAILURES[@]}" -ne 0 ] || [ "$WARNED" -ne 0 ]; then
        err "One or more initramfs rebuilds failed: ${FAILURES[*]:-none}. Initiating restore from backup."
        # Attempt restore
        restored=0
        for src in "$BACKUP_DIR"/*; do
            [ -f "$src" ] || continue
            if cp -v "$src" /boot/ 2>/dev/null; then
                restored=$((restored+1))
            else
                warn "Failed to restore $src to /boot"
            fi
        done
        info "Restored $restored files from backup."
        err "Restoration attempted. Check $LOGFILE and /boot for correctness."
        return 2
    fi

    info "All initramfs images rebuilt successfully and verified."
    return 0
}

# -------------------------
# Trigger: run DKMS rebuild then initramfs rebuild (idempotent guard)
# -------------------------
trigger_initramfs_rebuild() {
    info "Triggering DKMS rebuild + initramfs regeneration sequence."

    # Simple rate-limiter: if initramfs files updated in last 15 minutes, skip
    RECENT_COUNT=$(find /boot -maxdepth 1 -type f -name "initramfs*" -mmin -15 | wc -l)
    if [ "$RECENT_COUNT" -gt 0 ]; then
        info "Recent initramfs updates detected (<15m). Skipping rebuild to avoid thrash."
        return 0
    fi

    rebuild_nvidia_dkms_modules || warn "DKMS rebuild stage returned non-zero; continuing to initramfs step."

    if rebuild_initramfs_thorough; then
        info "Initramfs rebuild sequence completed successfully."
        # Optionally refresh bootloader configs for common bootloaders
        if command -v grub-mkconfig &>/dev/null; then
            info "Updating GRUB configuration..."
            progress_spinner_start
            grub-mkconfig -o /boot/grub/grub.cfg &>>"$LOGFILE" || warn "grub-mkconfig failed; check $LOGFILE"
            progress_spinner_stop
        fi
        return 0
    else
        err "Initramfs rebuild stage failed. See $LOGFILE for details."
        return 1
    fi
}

# -------------------------
# Verification routines (post-install) - Skip graphical in livecd/chroot
# -------------------------
verify_nvidia_install() {
    info "Running post-install diagnostics."

    # Check for DKMS modules
    info "Checking DKMS module for current kernel ($(uname -r))..."
    if ls /lib/modules/$(uname -r)/updates/dkms/nvidia.ko.xz &>/dev/null; then
        info "NVIDIA DKMS module found for current kernel."
    else
        warn "NVIDIA DKMS module missing for current kernel; reboot required."
    fi

    if [ "${MODE:-}" = "livecd" ] || [ -n "$CHROOTED" ]; then
        warn "Skipping nvidia-smi and vulkaninfo in livecd/chroot mode (no display/GPUs loaded)."
        return 0
    fi

    if command -v nvidia-smi &>/dev/null; then
        info "Running nvidia-smi..."
        if ! nvidia-smi &>>"$LOGFILE"; then
            warn "nvidia-smi failed to run; drivers may not be loaded."
        else
            info "nvidia-smi ran OK."
        fi
    else
        warn "nvidia-smi not found in PATH."
    fi

    if command -v vulkaninfo &>/dev/null; then
        # Set dummy env for headless
        export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"
        info "Running vulkaninfo..."
        if vulkaninfo | head -n 15 | tee -a "$LOGFILE"; then
            info "vulkaninfo ran OK."
        else
            warn "vulkaninfo failed; check env or reboot."
        fi
    else
        warn "vulkaninfo not available."
    fi

    info "Checking loaded modules..."
    lsmod | grep -E 'nvidia|nvidia_uvm|nvidia_modeset|nvidia_drm' || warn "NVIDIA kernel modules not visible via lsmod."
}

# -------------------------
# Main flow (modified for CHROOTED)
# -------------------------
main() {
    if [ -n "$CHROOTED" ]; then
        MODE="livecd"
        info "Running in chrooted LiveCD repair mode (auto-selected)."
        log "Execution mode: livecd (chrooted)"
        # Quick verification
        if [ -d "/run/archiso" ]; then
            warn "Live environment detected via bind mount. Proceeding in chroot."
        fi
    else
        select_mode  # Mode selection
    fi
    detect_distro
    install_nvidia_drivers || warn "Driver installation reported issues; continuing to attempt repairs."
    trigger_initramfs_rebuild || err "Trigger rebuild failed; check logs at $LOGFILE"
    verify_nvidia_install
    info "NVIDIA setup + initramfs maintenance complete (Mode: $MODE)."
}

# -------------------------
# Allow script to be sourced for selective functions or executed as main.
# -------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
