#!/usr/bin/env bash
set -euo pipefail
if pgrep -f "geoclue-2.0/demos/agent" > /dev/null; then
    echo "GeoClue agent is already running."
    exit 0
fi
AGENT_PATHS="/usr/libexec/geoclue-2.0/demos/agent /usr/lib/geoclue-2.0/demos/agent"
for path in $AGENT_PATHS; do
    if [ -x "$path" ]; then
        echo "Starting GeoClue agent from: $path"
        "$path" &
        exit 0
    fi
done
echo "GeoClue agent not found."
exit 1
