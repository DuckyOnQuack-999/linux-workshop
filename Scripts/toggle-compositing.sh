#!/bin/bash

# Script to toggle KDE compositing temporarily
# Requires: qdbus, kdialog

# Function to check if required commands are available
check_requirements() {
    local missing=()
    
    if ! command -v qdbus >/dev/null 2>&1; then
        missing+=("qdbus")
    fi
    
    if ! command -v kdialog >/dev/null 2>&1; then
        missing+=("kdialog")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Error: Missing required commands: ${missing[*]}"
        exit 1
    fi
}

# Function to check if compositing is active
check_compositing() {
    if ! command -v qdbus >/dev/null 2>&1; then
        echo "Error: qdbus is not installed"
        exit 1
    }
    
    status=$(qdbus org.kde.KWin /Compositor org.kde.kwin.Compositing.active 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Could not communicate with KWin"
        exit 1
    }
    echo "$status"
}

# Function to set compositing state (on/off)
set_compositing() {
    local state=$1
    qdbus org.kde.KWin /Compositor org.kde.kwin.Compositing.active "$state" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to set compositing state"
        exit 1
    }
}

# Main execution
# Check for required commands
check_requirements

echo "Checking initial compositing status..."
initial_status=$(check_compositing)

if [ "$initial_status" != "true" ]; then
    echo "Compositing is already disabled"
    exit 0
}

echo "Disabling compositing..."
set_compositing false
kdialog --passivepopup "Compositor disabled" 2 &

echo "Waiting 1 second..."
sleep 1

echo "Re-enabling compositing..."
set_compositing true
kdialog --passivepopup "Compositor enabled" 2 &

echo "Done!"
exit 0

