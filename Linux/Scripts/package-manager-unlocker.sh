#!/usr/bin/env bash
# ========================================================
# Unlock Package Manager Databases - Safe Removal Script
# Compatible with: Arch, Manjaro, Debian, Ubuntu, Fedora, openSUSE
# Author: duckyonquack-999 (QuackLabs Solutions)
# ========================================================

set -euo pipefail

echo "=== Package Manager Lock Remover ==="
echo "Detecting system and resolving lock issues..."
echo

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root."
    echo "Use: sudo $0"
    exit 1
fi

# Helper: kill process using a lock file
kill_process_using_lock() {
    local lock_file="$1"
    if [[ -f "$lock_file" ]]; then
        echo "[+] Lock file found: $lock_file"
        local pid
        pid=$(lsof "$lock_file" 2>/dev/null | awk 'NR==2 {print $2}')
        if [[ -n "$pid" ]]; then
            echo "[!] Process using lock (PID $pid):"
            ps -p "$pid" -o pid,cmd
            read -p "Terminate process $pid? [y/N]: " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                kill -9 "$pid" && echo "[✓] Process terminated."
            else
                echo "[i] Skipping process termination."
            fi
        fi
        echo "[*] Removing lock file..."
        rm -f "$lock_file" && echo "[✓] Removed: $lock_file"
    fi
}

# Arch/Manjaro (pacman)
if command -v pacman &>/dev/null; then
    echo "[Arch-based] Checking pacman locks..."
    kill_process_using_lock "/var/lib/pacman/db.lck"
fi

# Debian/Ubuntu (APT)
if command -v apt &>/dev/null || command -v apt-get &>/dev/null; then
    echo "[Debian-based] Checking APT locks..."
    kill_process_using_lock "/var/lib/dpkg/lock"
    kill_process_using_lock "/var/lib/dpkg/lock-frontend"
    kill_process_using_lock "/var/lib/apt/lists/lock"
    kill_process_using_lock "/var/cache/apt/archives/lock"

    echo "[*] Ensuring dpkg is configured properly..."
    dpkg --configure -a 2>/dev/null || true
fi

# Fedora/RHEL (DNF)
if command -v dnf &>/dev/null; then
    echo "[Fedora-based] Checking DNF locks..."
    kill_process_using_lock "/var/run/dnf.pid"
fi

# openSUSE (Zypper)
if command -v zypper &>/dev/null; then
    echo "[openSUSE-based] Checking Zypper locks..."
    kill_process_using_lock "/var/run/zypp.pid"
fi

# Nix (NixOS)
if command -v nix-env &>/dev/null; then
    echo "[NixOS] Checking Nix store locks..."
    kill_process_using_lock "/nix/var/nix/db/db.lock"
fi

# Clean-up summary
echo
echo "=== Summary ==="
echo "All detected lock files have been removed (if confirmed)."
echo "You may now safely use your package manager."
echo
echo "[Tip] Run your package manager again — example:"
echo "  sudo pacman -Syu"
echo
echo "=== Done ==="
