#!/usr/bin/env bash

# System status monitoring script
echo "=== Hyprland System Status ==="
echo

echo "Hyprland Version:"
hyprctl version | head -1
echo

echo "Active Windows:"
hyprctl clients | grep -c "class:" || echo "0"
echo

echo "Workspaces:"
hyprctl workspaces | grep -E "workspace [0-9]+" | wc -l
echo

echo "Monitors:"
hyprctl monitors | grep -c "Monitor" || echo "0"
echo

echo "Memory Usage:"
free -h | grep "Mem:"
echo

echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
echo

echo "Disk Usage:"
df -h / | tail -1
