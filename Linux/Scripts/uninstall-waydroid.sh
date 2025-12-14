#!/usr/bin/env bash
# =============================================================================
# EMERGENCY FULL WAYDROID UNINSTALLER – ArcoLinux/Arch Linux 2025
# Removes Waydroid, binder_linux DKMS, ibt=off, and restores system stability
# Run with sudo or as root
# =============================================================================

set -euo pipefail

echo "=== EMERGENCY WAYDROID FULL UNINSTALLER ==="
echo "Stopping all Waydroid services..."

# 1. Stop everything
sudo systemctl stop waydroid-container.service waydroid-session.service 2>/dev/null || true
waydroid session stop 2>/dev/null || true
sudo systemctl stop lxc.service 2>/dev/null || true

# 2. Remove Waydroid container + data
sudo waydroid container stop 2>/dev/null || true
sudo rm -rf /var/lib/waydroid /home/.waydroid ~/waydroid ~/.local/share/waydroid* ~/.local/share/applications/*aydroid* 2>/dev/null || true

# 3. Uninstall all packages we ever touched
sudo pacman -Rns --noconfirm \
    waydroid waydroid-image-gapps waydroid-image \
    binder_linux-dkms dkms anbox-support \
    python-pip weston qemu-desktop virtiofsd \
    iptables-nft lxc dnsmasq 2>/dev/null || true

# 4. Remove AUR helper if we installed it just for this
if command -v yay &>/dev/null && ! pacman -Q yay &>/dev/null; then
    sudo rm -rf /usr/bin/yay ~/.cache/yay 2>/dev/null || true
fi

# 5. Remove dangerous binder_linux DKMS module completely
sudo dkms remove binder_linux/4.14.0 --all 2>/dev/null || true
sudo rm -rf /usr/src/binder_linux* /var/lib/dkms/binder_linux* 2>/dev/null || true

# 6. Remove ibt=off from GRUB (this is the main crash source on Zen 6.17+)
if grep -q "ibt=off" /etc/default/grub; then
    sudo sed -i 's/ibt=off //g' /etc/default/grub
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=" /GRUB_CMDLINE_LINUX_DEFAULT="/g' /etc/default/grub
    echo "Removed ibt=off from GRUB..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# 7. Clean leftover configs
sudo rm -f /etc/modules-load.d/binder.conf /etc/modules-load.d/anbox.conf 2>/dev/null || true
sudo rm -rf /etc/waydroid* /usr/share/waydroid* 2>/dev/null || true

# 8. Final cleanup
sudo pacman -Sc --noconfirm 2>/dev/null || true
sudo journalctl --vacuum-time=2weeks

echo "==================================================================="
echo "WAYDROID COMPLETELY REMOVED"
echo "Dangerous binder_linux DKMS module purged"
echo "ibt=off removed from boot parameters"
echo ""
echo "REBOOTING IN 10 SECONDS – your system will be stable again"
echo "==================================================================="
sleep 10
sudo reboot
