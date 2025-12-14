#!/usr/bin/env bash
# =====================================================
# Full Razer Stack Installer for Linux (Drivers + CLI + GUI + Extras)
# Author: DuckyOnQuack-999 (Optimized by DuckyCoder AI)
# Version: 4.2
# Changes: Fixed unbound VERSION_ID on rolling distros (e.g., Arch) by using safe expansion ${VERSION_ID:-}; confirmed via os-release examples.
# Warning: OpenRazer has known vulnerabilities (e.g., CVE-2022-29022 buffer overflow, CVE-2022-23467 out-of-bounds read) - check for patches. Proceed with caution.
# Run as root: sudo bash this_script.sh
# =====================================================
set -euo pipefail
LOGFILE="/var/log/razer-full-install.log"
exec > >(tee -a "$LOGFILE") 2>&1
info() { printf '%s %s\n' "$(date --iso-8601=seconds)" "$*"; }
error() { info "ERROR: $*"; }
fatal() {
    info "FATAL: $*"
    exit 1
}
CURRENT_USER="${SUDO_USER:-$(whoami)}"
DISTRO=$(. /etc/os-release && echo "$ID")
VERSION_ID=$(. /etc/os-release && echo "${VERSION_ID:-}")
info "Detected distro: $DISTRO $VERSION_ID"
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fatal "This script must be run as root (use sudo)."
    fi
}
add_ubuntu_repo() {
    local ppa=$1
    local key_fingerprint=$2
    local key_ring=$3
    local repo_url=$4
    apt install -y software-properties-common curl gnupg || {
        error "Failed to install deps for repo addition."
        return 1
    }
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$key_fingerprint" | gpg --dearmor -o "/usr/share/keyrings/$key_ring" || {
        error "Key download failed for $ppa"
        return 1
    }
    echo "$repo_url" | tee "/etc/apt/sources.list.d/${ppa%%/*}.list" || {
        error "Repo file creation failed"
        return 1
    }
    apt update || {
        error "apt update failed after repo add"
        return 1
    }
    return 0
}
add_obs_repo() {
    local distro_name=$1
    local version=$2
    local key_ring=$3
    local repo_url=$4
    curl -fsSL "https://download.opensuse.org/repositories/hardware:/razer/$distro_name_$version/Release.key" | gpg --dearmor -o "/usr/share/keyrings/$key_ring" || {
        error "OBS key download failed"
        return 1
    }
    echo "$repo_url" | tee "/etc/apt/sources.list.d/hardware-razer.list" || {
        error "OBS repo file creation failed"
        return 1
    }
    apt update || {
        error "apt update failed after OBS add"
        return 1
    }
    return 0
}
install_core_stack() {
    info "Installing core stack (OpenRazer, Polychromatic)..."
    if command -v openrazer-daemon >/dev/null 2>&1 && command -v polychromatic-controller >/dev/null 2>&1; then
        info "Core stack already installed - skipping."
        return
    fi
    case "$DISTRO" in
    arch | manjaro)
        pacman -Syu --noconfirm base-devel git python-dbus python-pyudev dkms linux-headers openrazer-meta polychromatic || {
            error "Arch install failed"
            return 1
        }
        ;;
    ubuntu | pop | kali | linuxmint | elementary | zorin)
        apt update || fatal "apt update failed"
        apt install -y git python3-dbus python3-pyudev dkms linux-headers-"$(uname -r)" || error "deps failed"
        # OpenRazer PPA
        if ! add_ubuntu_repo "openrazer" "903936CAB6049E2E6C33D5D8073E051D7B2AEE37" "openrazer.gpg" "deb [signed-by=/usr/share/keyrings/openrazer.gpg] https://ppa.launchpadcontent.net/openrazer/stable/ubuntu $(lsb_release -cs) main"; then
            error "OpenRazer PPA failed - attempting OBS fallback..."
            add_obs_repo "$(lsb_release -si)" "$(lsb_release -sr)" "hardware-razer.gpg" "deb [signed-by=/usr/share/keyrings/hardware-razer.gpg] https://download.opensuse.org/repositories/hardware:/razer/$(lsb_release -si)_$(lsb_release -sr)/ /" || fatal "OBS fallback failed - check network or manual install from https://openrazer.github.io"
        fi
        # Polychromatic PPA
        if ! add_ubuntu_repo "polychromatic" "C0D54C34D00160459588000E96B9CD7C22E2C8C5" "polychromatic.gpg" "deb [signed-by=/usr/share/keyrings/polychromatic.gpg] https://ppa.launchpadcontent.net/polychromatic/stable/ubuntu $(lsb_release -cs) main"; then
            error "Polychromatic PPA failed - check https://polychromatic.app/download/ for alternatives."
            return 1
        fi
        apt install -y openrazer-meta polychromatic || {
            error "Core install failed - enable universe repo or check dependencies."
            return 1
        }
        ;;
    debian)
        apt update || fatal "apt update failed"
        apt install -y git python3-dbus python3-pyudev dkms linux-headers-"$(uname -r)" || error "deps failed"
        # Use OBS for Debian
        add_obs_repo "Debian" "$VERSION_ID" "hardware-razer.gpg" "deb [signed-by=/usr/share/keyrings/hardware-razer.gpg] https://download.opensuse.org/repositories/hardware:/razer/Debian_$VERSION_ID/ /" || fatal "OBS add failed for Debian"
        apt install -y openrazer-meta polychromatic || {
            error "Core install failed for Debian."
            return 1
        }
        ;;
    fedora | nobara)
        dnf install -y kernel-devel || error "kernel-devel failed"
        dnf config-manager addrepo --from-repofile=https://openrazer.github.io/hardware:razer.repo || {
            error "Repo add failed - fallback to direct"
            dnf config-manager --add-repo https://download.opensuse.org/repositories/hardware:/razer/Fedora_"${VERSION_ID}"/hardware:razer.repo || return 1
        }
        dnf copr enable lah7/polychromatic || error "COPR failed - enable manually"
        dnf install -y openrazer-meta polychromatic python3-dbus python3-pyudev dkms || {
            error "Fedora install failed - check repo keys or versions."
            return 1
        }
        ;;
    opensuse* | suse)
        zypper addrepo https://download.opensuse.org/repositories/hardware:razer/openSUSE_Tumbleweed/hardware:razer.repo || {
            error "Repo add failed - adjust for Leap if needed"
            return 1
        }
        zypper refresh || error "Refresh failed"
        zypper install -y openrazer-meta polychromatic python3-dbus python3-pyudev dkms kernel-devel || {
            error "openSUSE install failed - check OBS for updates."
            return 1
        }
        ;;
    *)
        fatal "Unsupported distro: $DISTRO"
        ;;
    esac
}
install_guis() {
    info "Installing GUI (RazerGenie)..."
    if command -v razergenie >/dev/null 2>&1; then
        info "RazerGenie already installed - skipping."
        return
    fi
    case "$DISTRO" in
    arch | manjaro)
        info "For AUR packages on Arch, switching to user $CURRENT_USER for build (assumes passwordless sudo for pacman)..."
        if ! su "$CURRENT_USER" -c "command -v yay >/dev/null 2>&1"; then
            info "Installing yay AUR helper as user..."
            su "$CURRENT_USER" -c "mkdir -p \$HOME/.aur_tmp && git clone https://aur.archlinux.org/yay.git \$HOME/.aur_tmp/yay && cd \$HOME/.aur_tmp/yay && makepkg -si --noconfirm && rm -rf \$HOME/.aur_tmp" || {
                error "yay install failed - install manually: https://github.com/Jguer/yay"
                return 1
            }
        fi
        su "$CURRENT_USER" -c "gpg --keyserver hkps://keys.openpgp.org --recv-keys BD04DA24C971B8D587B2B8D7FAF69CF6CD2D02CD" || info "GPG key import skipped (may already exist or server issue)"
        su "$CURRENT_USER" -c "yay -S --noconfirm --needed razergenie" || {
            error "Arch razergenie failed - check AUR status or install manually: git clone https://aur.archlinux.org/razergenie.git && makepkg -si"
            return 1
        }
        ;;
    ubuntu | debian | pop | kali | linuxmint | elementary | zorin)
        # Assume added via core stack OBS/PPA; install if available
        apt install -y razergenie || {
            error "Ubuntu/Debian GUI failed - ensure OBS repo added or check https://software.opensuse.org/download.html?project=hardware%3Arazer&package=razergenie"
            return 1
        }
        ;;
    fedora | nobara)
        dnf install -y razergenie || {
            error "Fedora GUI failed - ensure repo added."
            return 1
        }
        ;;
    opensuse* | suse)
        zypper install -y razergenie || {
            error "openSUSE GUI failed - check OBS."
            return 1
        }
        ;;
    esac
}
install_extras() {
    info "Installing extras (Python bindings, dev tools)..."
    # Python bindings installed via distro packages; skip pip unless needed
    info "Extras handled by core packages - skipping additional installs."
}
setup_user() {
    info "Setting up user groups..."
    groupadd -f plugdev || error "groupadd failed"
    usermod -aG plugdev "$CURRENT_USER" || error "usermod failed - check user exists"
}
enable_services() {
    info "Enabling services..."
    systemctl enable --now openrazer-daemon.service || error "openrazer-daemon enable failed - check if installed"
    systemctl enable --now dkms.service || error "DKMS enable failed - may not be needed"
}
verify_install() {
    info "Verifying installation..."
    local success=true
    if ! command -v openrazer-daemon >/dev/null 2>&1; then
        error "Daemon missing"
        success=false
    fi
    if ! systemctl is-active --quiet openrazer-daemon.service; then
        error "Daemon not running - try systemctl start openrazer-daemon"
        success=false
    fi
    if ! lsmod | grep -q razer; then
        modprobe razerkbd razermouse razerkraken || error "Modules load failed - check dkms"
        success=false
    fi
    if ! command -v polychromatic-controller >/dev/null 2>&1; then
        error "Polychromatic missing"
        success=false
    fi
    if command -v razergenie >/dev/null 2>&1; then
        info "RazerGenie installed."
    else
        info "RazerGenie optional - not installed."
    fi
    if [ "$success" = false ]; then
        error "Verification failed - troubleshooting: Reboot, check groups (plugdev), disable Secure Boot, verify kernel headers match uname -r."
        fatal "See log for details."
    fi
    info "Verification successful."
}
main() {
    require_root
    install_core_stack || fatal "Core stack failed - see errors above for fixes."
    install_guis || error "GUI failed - continuing without."
    install_extras || error "Extras failed - optional, continuing."
    setup_user
    enable_services
    verify_install
    info "Installation complete for $CURRENT_USER. Reboot recommended."
    info "Log: $LOGFILE"
}
main

