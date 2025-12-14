#!/usr/bin/env bash
#
# Armagetron Advanced Source Downloader Script
# Options to pull official source for 0.2.8, 0.2.9, 0.4 (experimental) & GitLab mirror
# Includes logic, error handling, and directory setup.

# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

BASE_DIR="$HOME/armagetron_sources"
mkdir -p "$BASE_DIR"
echo "Sources will be stored under: $BASE_DIR"
sleep 1

# ─────────────────────────────────────────────────────────────────────────────
function show_menu() {
    clear
    echo "——————————————————————————————————————"
    echo " Armagetron Advanced Source Downloader"
    echo "——————————————————————————————————————"
    echo "1) Clone Official 0.2.8 Source (bazaar)"
    echo "2) Clone Official 0.2.9 Source (bazaar)"
    echo "3) Clone Official Trunk / 0.4 Experimental (bazaar)"
    echo "4) Clone GitLab Mirror (trunk + tags) (git)"
    echo "5) Download 0.2.9 Source Tarball"
    echo "6) Quit"
    echo "——————————————————————————————————————"
    read -rp "Choose an option (1-6): " CHOICE
}

# ─────────────────────────────────────────────────────────────────────────────
function clone_bzr() {
    local branch="$1"
    local dest="$BASE_DIR/$(basename "$branch")"
    echo
    echo "📥 Cloning Bazaar branch: $branch"
    echo "Destination: $dest"
    if command -v bzr >/dev/null 2>&1; then
        bzr branch "$branch" "$dest"
        echo "✅ Done! Code at: $dest"
    else
        echo "❌ 'bzr' not installed. Install with your package manager."
    fi
    sleep 2
}

function clone_git() {
    local repo="$1"
    local dest="$BASE_DIR/$(basename "$repo" .git)"
    echo
    echo "📥 Cloning Git repository: $repo"
    echo "Destination: $dest"
    git clone "$repo" "$dest"
    echo "✅ Done! Code at: $dest"
    sleep 2
}

function download_tarball() {
    local url="$1"
    local dest="$BASE_DIR/$(basename "$url")"
    echo
    echo "⬇️ Downloading tarball: $url"
    curl -L "$url" -o "$dest"
    echo "📦 Download complete: $dest"
    sleep 2
}

# ─────────────────────────────────────────────────────────────────────────────
while true; do
    show_menu
    case "$CHOICE" in

    1)
        # Official 0.2.8 via Bazaar
        clone_bzr "lp:armagetronad/0.2.8"
        ;;

    2)
        # Official 0.2.9 via Bazaar
        clone_bzr "lp:armagetronad/0.2.9"
        ;;

    3)
        # Trunk / Experimental 0.4 via Bazaar
        clone_bzr "lp:armagetronad"
        ;;

    4)
        # GitLab Mirror (trunk + tags)
        clone_git "https://gitlab.com/armagetronad/armagetronad.git"
        ;;

    5)
        # 0.2.9 source tarball (Ubuntu source package example)
        download_tarball "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/armagetronad/0.2.9.1.1-1build4/armagetronad_0.2.9.1.1.orig.tar.gz"
        ;;

    6)
        echo "✌️ Goodbye!"
        exit 0
        ;;

    *)
        echo "⚠️ Invalid option, try again."
        sleep 1
        ;;
    esac
done
