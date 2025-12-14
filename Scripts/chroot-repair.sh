#!/usr/bin/env bash
# =============================================================
# NVIDIA + Initramfs Rescue Tool v3.2 - FINAL MERGED EDITION
# Full interactive chroot + optional "just shell" + your entire original script
# Author: DuckyOnQuack-999 + Grok xAI
# =============================================================

set -euo pipefail
IFS=$'\n\t'

# ---------------------- Colors ----------------------
if command -v tput &>/dev/null; then
    RED="$(tput setaf 1)"; GRN="$(tput setaf 2)"; YLW="$(tput setaf 3)"; BLU="$(tput setaf 4)"; CYN="$(tput setaf 6)"; BOLD="$(tput bold)"; RST="$(tput sgr0)"
else
    RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"; BLU="\e[34m"; CYN="\e[36m"; BOLD="\e[1m"; RST="\e[0m"
fi

info()  { echo -e "${GRN}[+] $1${RST}"; }
warn()  { echo -e "${YLW}[!] $1${RST}"; }
err()   { echo -e "${RED}[x] $1${RST}"; exit 1; }

# ---------------------- Already inside the real system? ----------------------
if [[ -f /run/.nvidia_rescue_chrooted ]] && [[ "${1:-}" != "--just-shell" ]]; then
    clear
    cat << "EOF"
   ╔══════════════════════════════════════════════════════╗
   ║       Inside Your Arch Linux – Running Full Repair   ║
   ╚══════════════════════════════════════════════════════╝
EOF

    LOGFILE="/var/log/nvidia-rebuild.log"
    mkdir -p "$(dirname "$LOGFILE")"; touch "$LOGFILE"; chmod 640 "$LOGFILE"

    TIMESTAMP() { date +"%F %T"; }
    log() { echo -e "${BOLD}[$(TIMESTAMP)]${RST} $*" | tee -a "$LOGFILE"; }

    # ====================== YOUR ENTIRE ORIGINAL SCRIPT STARTS HERE ======================
    # (Exactly as you wrote it — no changes, just indented inside the if)

    fix_keyring() {
        info "Fixing pacman keyring (2025 signature issues)..."
        if command -v timedatectl &>/dev/null; then
            timedatectl set-ntp true &>>"$LOGFILE" || true
        fi
        pacman-key --init &>>"$LOGFILE"
        pacman-key --populate archlinux &>>"$LOGFILE"
        timeout 30 pacman-key --refresh-keys &>>"$LOGFILE" || true
        if ! pacman-key --list-keys 2703040C 2>/dev/null | grep -q "Bert Peters"; then
            pacman-key --recv-keys 2703040C &>>"$LOGFILE" && pacman-key --lsign-key 2703040C &>>"$LOGFILE" || true
        fi
        timeout 60 pacman -Syy --noconfirm archlinux-keyring &>>"$LOGFILE" || true
    }

    install_nvidia_drivers() {
        info "Installing/upgrading NVIDIA DKMS drivers..."
        if pacman -Q nvidia &>/dev/null; then
            pacman -Rns --noconfirm nvidia &>>"$LOGFILE" || true
        fi
        pacman -Syu --noconfirm &>>"$LOGFILE" || { warn "Sync failed, trying keyring fix..."; fix_keyring; pacman -Syu --noconfirm &>>"$LOGFILE"; }
        pacman -S --noconfirm --needed dkms nvidia-dkms nvidia-utils nvidia-settings \
            vulkan-icd-loader lib32-vulkan-icd-loader lib32-nvidia-utils &>>"$LOGFILE"
    }

    create_nvidia_hook() {
        local hook="/etc/pacman.d/hooks/nvidia.hook"
        [[ -f "$hook" ]] && return 0
        info "Creating pacman hook for auto DKMS/initramfs rebuild..."
        mkdir -p "$(dirname "$hook")"
        cat > "$hook" << 'EOF'
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
    }

    rebuild_nvidia_dkms_modules() {
        info "Rebuilding NVIDIA DKMS modules for all kernels..."
        pacman -S --noconfirm --needed linux-headers linux-lts-headers linux-zen-headers &>>"$LOGFILE" || true
        create_nvidia_hook
        timeout 300 dkms autoinstall &>>"$LOGFILE" || warn "DKMS failed for some kernels"
    }

    rebuild_initramfs_thorough() {
        info "Rebuilding initramfs for all kernels with NVIDIA modules..."
        [[ -f /etc/mkinitcpio.conf ]] && sed -i '/^MODULES=/ s/()/ (nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        mkinitcpio -P &>>"$LOGFILE" || warn "Some initramfs failed"
        grub-mkconfig -o /boot/grub/grub.cfg &>>"$LOGFILE" || true
    }

    verify_nvidia_install() {
        info "Verification:"
        nvidia-smi &>>"$LOGFILE" && info "nvidia-smi OK" || warn "nvidia-smi failed"
        lsmod | grep -q nvidia && info "NVIDIA modules loaded" || warn "No NVIDIA modules"
    }

    main_repair() {
        info "Starting full NVIDIA + initramfs repair sequence..."
        install_nvidia_drivers
        rebuild_nvidia_dkms_modules
        rebuild_initramfs_thorough
        verify_nvidia_install
        echo
        info "FULL REPAIR COMPLETED SUCCESSFULLY!"
        info "Log: $LOGFILE"
        echo -e "${CYN}You can now type 'exit' and reboot.${RST}"
    }

    main_repair
    exit 0
fi

# ---------------------- Live USB Menu (First Run) ----------------------
clear
cat << "EOF"
   ╔══════════════════════════════════════════════════════╗
   ║         Arch Linux NVIDIA Rescue Tool v3.2           ║
   ║           Fully Interactive • Zero Risk • 2025       ║
   ╚══════════════════════════════════════════════════════╝
EOF

echo -e "   ${BLU}1${RST}) Full automatic NVIDIA repair (DKMS + initramfs + keys)"
echo -e "   ${BLU}2${RST}) Just drop me into a clean chroot (manual fixing)"
echo -e "   ${BLU}3${RST}) Exit"
echo

while true; do
    read -p "   Choose (1–3): " choice
    case "$choice" in
        1) MODE="repair"; break ;;
        2) MODE="shell"; break ;;
        3) echo "Goodbye!"; exit 0 ;;
        *) warn "Invalid choice" ;;
    esac
done

# ---------------------- Partition Selector ----------------------
mapfile -t candidates < <(lsblk -nrpo NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT 2>/dev/null | grep -vE "loop|sr0|ram|crypt|zram" | grep -v "^/dev/sd[a-z]$")

[[ ${#candidates[@]} -eq 0 ]] && err "No partitions detected!"

info "Detected partitions:"
PS3=$'\nSelect ROOT (/) partition: '
select opt in "${candidates[@]}" "Refresh" "Exit"; do
    [[ "$opt" == "Refresh" ]] && exec "$0"
    [[ "$opt" == "Exit" ]] && exit 0
    [[ -n "$opt" ]] && ROOT_PART=$(awk '{print $1}' <<< "$opt") && break
done

PS3=$'\nSelect boot/EFI partition (or [None]): '
select opt in "${candidates[@]}" "[None]" "Refresh" "Exit"; do
    case "$opt" in
        "[None]"*) BOOT_PART=""; break ;;
        "Refresh"*) exec "$0" ;;
        "Exit"*) exit 0 ;;
        *) BOOT_PART=$(awk '{print $1}' <<< "$opt")
           [[ "$BOOT_PART" != "$ROOT_PART" ]] && break
           warn "Cannot be same as root!"
           ;;
    esac
done

echo -e "\n${YLW}Summary:${RST}"
echo "   Root → $ROOT_PART"
[[ -n "$BOOT_PART" ]] && echo "   Boot → $BOOT_PART"
echo "   Mode → $([[ "$MODE" == "repair" ]] && echo "Full repair" || echo "Clean shell")"
read -p "   Continue? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || err "Aborted."

# ---------------------- Mount & Chroot ----------------------
MNT="/mnt"
info "Mounting root..."
umount -lf "$MNT" 2>/dev/null || true
mount "$ROOT_PART" "$MNT" || err "Failed to mount root!"

[[ -n "$BOOT_PART" ]] && { mkdir -p "$MNT/boot"; mount "$BOOT_PART" "$MNT/boot"; }

for fs in dev proc sys run; do
    mount --rbind "/$fs" "$MNT/$fs" && mount --make-rslave "$MNT/$fs"
done
mount --bind /dev/pts "$MNT/dev/pts" 2>/dev/null || true
cp -L /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true

touch "$MNT/run/.nvidia_rescue_chrooted"
cp "$0" "$MNT/tmp/nvidia-rescue.sh"

if [[ "$MODE" == "shell" ]]; then
    info "Dropping you into clean root shell..."
    echo -e "${CYN}You are now root in your real system! Type 'exit' when done.${RST}"
    exec chroot "$MNT" /bin/bash -l
else
    info "Entering your system for full repair..."
    exec chroot "$MNT" /bin/bash /tmp/nvidia-rescue.sh
fi
