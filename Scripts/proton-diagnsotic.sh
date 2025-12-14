#!/usr/bin/env bash
set -euo pipefail

echo "=== Environment detection ==="
echo "User: $(whoami)"
echo "Distro (lsb):" && { command -v lsb_release >/dev/null 2>&1 && lsb_release -a || echo "lsb_release not present"; }
echo "Kernel: $(uname -r)"
echo

echo "=== Steam install detection ==="
echo "Flatpak Steam present?"
flatpak info com.valvesoftware.Steam >/dev/null 2>&1 && echo "yes (flatpak)" || echo "no (flatpak)"
echo "Snap Steam present?"
snap list steam >/dev/null 2>&1 && echo "yes (snap)" || echo "no (snap)"
echo "Native Steam paths check:"
echo "  ~/.local/share/Steam -> $([ -d ~/.local/share/Steam ] && echo "exists" || echo "missing")"
echo "  ~/.steam/root -> $([ -d ~/.steam/root ] && echo "exists" || echo "missing")"
echo

echo "=== Proton / compatibilitytools.d ==="
echo "compatibilitytools.d (native) -> ~/.steam/root/compatibilitytools.d -> $([ -d ~/.steam/root/compatibilitytools.d ] && ls -1 ~/.steam/root/compatibilitytools.d || echo 'missing')"
echo "compatibilitytools.d (local Steam) -> ~/.local/share/Steam/compatibilitytools.d -> $([ -d ~/.local/share/Steam/compatibilitytools.d ] && ls -1 ~/.local/share/Steam/compatibilitytools.d || echo 'missing')"
echo "compatibilitytools.d (flatpak path) -> ~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d -> $([ -d ~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d ] && ls -1 ~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d || echo 'missing')"
echo

echo "=== Installed Proton versions (steamapps/common) ==="
if compgen -G "~/.steam/root/steamapps/common/Proton*" >/dev/null; then ls -d ~/.steam/root/steamapps/common/Proton* || true; else echo "none in ~/.steam/root/steamapps/common"; fi
if compgen -G "~/.local/share/Steam/steamapps/common/Proton*" >/dev/null; then ls -d ~/.local/share/Steam/steamapps/common/Proton* || true; else echo "none in ~/.local/share/Steam/steamapps/common"; fi
echo

echo "=== Steam process / version ==="
ps -ef | grep -i steam | grep -v grep || echo "steam not running"
echo "Steam binary (which): $(command -v steam || echo 'not in PATH')"
echo "Steam version file (if present):"
[ -f ~/.steam/root/package/steam_manifest.txt ] && echo "manifest: ~/.steam/root/package/steam_manifest.txt exists" || echo "no manifest found"
echo

echo "=== GPU + 32-bit libraries check (Manjaro/Arch style) ==="
echo "NVIDIA driver packages (pacman query):"
pacman -Qs '^nvidia' || echo "pacman not present or no nvidia packages"
echo "Look for lib32 vulkan/mesa packages:"
pacman -Qs lib32 | egrep 'vulkan|mesa|libgl' || true
echo

echo "=== Steam compatdata directories (example listing) ==="
ls -1 ~/.local/share/Steam/steamapps/compatdata 2>/dev/null | head -n 20 || echo "compatdata missing or empty"
echo

echo "=== Permissions check (examples) ==="
echo "Steam home dir ownership:"
ls -ld ~/.steam ~/.local/share/Steam ~/.var/app/com.valvesoftware.Steam 2>/dev/null || true
echo

echo "=== Diagnostic complete ==="
echo
echo "Next steps:"
echo " - If Steam is Flatpak or Snap, prefer using native Steam (pacman/pamac) for easier Proton access."
echo " - If compatibilitytools.d is missing: install Proton/G E or use ProtonUp-Qt to add versions. (See Proton-GE docs.)"
echo " - If compatdata/<appid> exists and game fails: try removing that game's compatdata to force a rebuild."
echo
echo "CITATIONS: Proton-GE install paths & Steam troubleshooting docs (See ArchWiki, Proton README, Proton-GE README)."
