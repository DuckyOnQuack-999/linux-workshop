#!/usr/bin/env bash
set -euo pipefail
if [[ -z "$1" ]]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi
if [[ -d "$1" ]]; then
    cp -r "$1/"* "$HOME/.config/hypr/" || {
        echo "Error: Failed to restore backup from $1"
        exit 1
    }
    echo "Restored backup from $1"
else
    echo "Backup directory not found: $1"
    exit 1
fi
