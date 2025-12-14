#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [-d device] [-m mountpoint]"
    echo "Options:"
    echo "  -d device      Specify the device to check (optional)"
    echo "  -m mountpoint  Specify the mount point to check (optional)"
    echo "  -h             Display this help message"
    exit 1
}

# Parse command line options
while getopts "d:m:h" opt; do
    case $opt in
        d) DEVICE="$OPTARG";;
        m) MOUNTPOINT="$OPTARG";;
        h) usage;;
        \?) usage;;
    esac
done

# Validate parameters if provided
if [[ -n "$DEVICE" && ! -e "$DEVICE" ]]; then
    echo "Error: Device $DEVICE does not exist"
    exit 1
fi

if [[ -n "$MOUNTPOINT" && ! -d "$MOUNTPOINT" ]]; then
    echo "Error: Mount point $MOUNTPOINT is not a directory"
    exit 1
fi

# Build the status command
STATUS_CMD="/home/duckyonquack999/GitHub-Repositories/dotfiles/Linux/Scripts/ntfs-mounter.sh --status"
if [[ -n "$DEVICE" || -n "$MOUNTPOINT" ]]; then
    [[ -n "$DEVICE" ]] && STATUS_CMD+=" --device $DEVICE"
    [[ -n "$MOUNTPOINT" ]] && STATUS_CMD+=" --mountpoint $MOUNTPOINT"
fi

# Get the status from ntfs-mounter
status_output=$(sudo $STATUS_CMD)

# Check if the command was successful
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get mount status"
    exit 1
fi

# Display the status in a wofi window
echo "$status_output" | wofi --show dmenu \
    --width 800 \
    --height 400 \
    --dmenu \
    --prompt "NTFS Mount Status" \
    --cache-file /dev/null \
    --insensitive \
    --lines 20
