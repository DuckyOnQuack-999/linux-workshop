#!/bin/bash

# Configuration
REPO_DIR="/home/duckyonquack999/GitHub-Repositories"
LOG_FILE="/home/duckyonquack999/.local/share/github-repos-scanner.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Error handling function
error() {
    log "ERROR: $1"
    echo "ERROR: $1" >&2
}

# Check if directory exists
if [ ! -d "$REPO_DIR" ]; then
    error "Repository directory $REPO_DIR does not exist!"
    exit 1
fi

log "Starting GitHub repository scan"

# Scan for repositories
find "$REPO_DIR" -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
    # Check if it's a git repository
    if [ -d "$dir/.git" ]; then
        repo_name=$(basename "$dir")
        log "Found repository: $repo_name"
        
        # Try to add to GitHub Desktop
        if github-desktop -a "$dir" 2>/dev/null; then
            log "Successfully added $repo_name to GitHub Desktop"
        else
            # If error code is 0, repository was already added
            if [ $? -eq 0 ]; then
                log "Repository $repo_name is already in GitHub Desktop"
            else
                error "Failed to add $repo_name to GitHub Desktop"
            fi
        fi
    fi
done

log "Scan completed"

