#!/usr/bin/env bash

# Enhanced sleep script with proper power management
case "$1" in
    "suspend")
        echo "Suspending system..."
        systemctl suspend
        ;;
    "hibernate")
        echo "Hibernating system..."
        systemctl hibernate
        ;;
    "lock")
        echo "Locking screen..."
        hyprlock
        ;;
    *)
        echo "Usage: $0 {suspend|hibernate|lock}"
        ;;
esac
