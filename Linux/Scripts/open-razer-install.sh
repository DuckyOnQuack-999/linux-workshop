#!/usr/bin/env bash
# =====================================================
# Full Razer Stack Installer for Linux (Drivers + CLI + GUI + Extras)
# Author: DuckyOnQuack-999
# =====================================================

set -euo pipefail
LOGFILE="/var/log/razer-full-install.log"
exec > >(tee -a "$LOGFILE") 2>&1

info() { printf '%s %s\n' "$(date --iso-8601=seconds)" "$*"; }
fatal() {
    info "FATAL: $*"
    exit 1
}

CURRENT_USER=$(logname 2>/dev/null || echo "$USER")

# Detect distro and package manager
detect_distro() {
    . /etc/os-release 2>/dev/null || fatal "Cannot find /etc/os-release"
    echo "$ID"
}
DISTRO=$(detect_distro)
info "Detected distro: $DISTRO"

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            info "Using sudo to elevate..."
            exec sudo bash "$0" "$@"
        else
            info "sudo not found — installing sudo..."
            install_sudo
            exec sudo bash "$0" "$@"
        fi
        exit 0
    fi
}

install_sudo() {
    info "Installing or repairing sudo..."
    case "$DISTRO" in
    arch | manjaro)
        pacman -Sy --noconfirm sudo || fatal "pacman install sudo failed"
        usermod -aG wheel "$CURRENT_USER" || info "usermod wheel failed"
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || info "Could not edit /etc/sudoers"
        ;;
    ubuntu | debian | pop | kali)
        apt update && apt install -y sudo || fatal "apt install sudo failed"
        usermod -aG sudo "$CURRENT_USER" || info "usermod sudo failed"
        sed -i 's/^# %sudo ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) ALL/' /etc/sudoers || info "Could not edit /etc/sudoers"
        ;;
    fedora)
        dnf install -y sudo || fatal "dnf install sudo failed"
        usermod -aG wheel "$CURRENT_USER" || info "usermod wheel failed"
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || info "Could not edit /etc/sudoers"
        ;;
    opensuse* | suse)
        zypper install -y sudo || fatal "zypper install sudo failed"
        usermod -aG wheel "$CURRENT_USER" || info "usermod wheel failed"
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || info "Could not edit /etc/sudoers"
        ;;
    *)
        fatal "Unsupported distro: $DISTRO"
        ;;
    esac
    info "sudo setup complete."
}

install_core_stack() {
    info "Installing core driver/daemon/CLI/GUI stack..."
    case "$DISTRO" in
    arch | manjaro)
        pacman -Sy --noconfirm base-devel git python-dbus python-pyudev dkms linux-headers || info "base deps failed"
        pacman -S --noconfirm openrazer-daemon openrazer-librazor python-openrazer polychromatic razer-cli razercommander ||
            info "Some packages not available, fallback may be required"
        ;;
    ubuntu | debian | pop | kali)
        apt update
        apt install -y software-properties-common curl git python3-dbus python3-pyudev dkms linux-headers-$(uname -r) || info "deps install failed"
        add-apt-repository -y ppa:openrazer/stable || info "Adding openrazer ppa failed"
        add-apt-repository -y ppa:polychromatic/stable || info "Adding polychromatic ppa failed"
        apt update
        apt install -y openrazer-daemon razer-cli polychromatic razercommander python3-openrazer || info "openrazer install failed"
        ;;
    fedora)
        dnf install -y openrazer-daemon razer-cli polychromatic razercommander python3-dbus python3-pyudev dkms kernel-devel || info "install failed"
        ;;
    opensuse* | suse)
        zypper install -y openrazer-daemon razer-cli polychromatic python3-dbus python3-pyudev dkms kernel-devel || info "install failed"
        ;;
    *)
        fatal "Unsupported distro for core stack: $DISTRO"
        ;;
    esac
}

install_extras() {
    info "Installing extras: Chroma SDK libraries, Python bindings, developer tools..."
    # Python Chroma SDK library
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --upgrade pip setuptools wheel || info "pip upgrade failed"
        pip3 install chroma-python pychroma || info "Install chroma-python/pychroma failed"
    else
        info "pip3 not found — attempting to install"
        case "$DISTRO" in
        arch | manjaro)
            pacman -S --noconfirm python-pip || info "Install python-pip failed"
            pip3 install chroma-python pychroma || info "Install pip extras failed"
            ;;
        ubuntu | debian | pop | kali)
            apt install -y python3-pip || info "Install python3-pip failed"
            pip3 install chroma-python pychroma || info "Install pip extras failed"
            ;;
        *)
            info "pip install fallback not implemented for this distro"
            ;;
        esac
    fi
    # Developer tool: clone openrazer repo tools if desired
    git clone https://github.com/openrazer/openrazer.git /usr/local/src/openrazer-tools || info "Clone openrazer repo failed"
    info "Extras installed."
}

verify_and_enable() {
    info "Verifying setup: kernel module, service, user groups, udev rules..."
    # Kernel module
    if ! lsmod | grep -iq razer; then
        info "Kernel modules not loaded; attempting modprobe..."
        modprobe razerkbd 2>/dev/null || true
        modprobe razermouse 2>/dev/null || true
        modprobe razerkraken 2>/dev/null || true
    fi
    # Service file creation if missing
    if ! systemctl list-unit-files | grep -q "openrazer-daemon.service"; then
        info "Service file missing — creating manually..."
        cat >/etc/systemd/system/openrazer-daemon.service <<'EOF'
[Unit]
Description=OpenRazer Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/openrazer-daemon --foreground
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
    fi
    # Enable & start
    systemctl enable --now openrazer-daemon.service || info "Enable/start service failed"
    # User group
    groupadd -f plugdev || true
    usermod -aG plugdev "$CURRENT_USER" || info "usermod plugdev failed"
    # udev reload
    udevadm control --reload-rules || info "udev reload failed"
    udevadm trigger || info "udev trigger failed"
    info "Verification complete."
}

main() {
    require_root "$@"
    install_sudo
    install_core_stack
    install_extras
    verify_and_enable
    info "Full Razer stack installation complete for user $CURRENT_USER."
    info "Please reboot or log out/in to activate group changes and modules."
    info "Log file: $LOGFILE"
}

main "$@"
