#!/usr/bin/env bash
set -euo pipefail
POLKIT_AGENTS=(
    "/usr/lib/polkit-kde-authentication-agent-1"
    "/usr/libexec/polkit-kde-authentication-agent-1"
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    "/usr/libexec/polkit-gnome/polkit-gnome-authentication-agent-1"
)
if pgrep -f "polkit-.*-authentication-agent" > /dev/null; then
    echo "Polkit agent is already running."
    exit 0
fi
for agent in "${POLKIT_AGENTS[@]}"; do
    if [[ -x "$agent" ]]; then
        echo "Starting polkit agent: $agent"
        "$agent" &
        exit 0
    fi
done
echo "No polkit agent found. Installing polkit-gnome as fallback..."
yay -S --needed polkit-gnome || {
    echo "Error: Failed to install polkit-gnome"
    exit 1
}
if [[ -x "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1" ]]; then
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
    echo "Started polkit-gnome agent"
else
    echo "Error: No polkit agent could be started"
    exit 1
fi
