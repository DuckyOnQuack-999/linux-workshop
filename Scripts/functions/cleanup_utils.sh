#!/bin/bash

system_cleanup() {
    print_info "Starting System Cleanup..."
    
    # Clean package cache
    print_info "Cleaning package cache..."
    if command -v paccache &>/dev/null; then
        sudo paccache -r
    else
        print_warning "paccache not found. Skipping package cache cleanup."
    fi
    
    # Remove orphaned packages
    print_info "Checking for orphaned packages..."
    if command -v pacman &>/dev/null; then
        orphans=$(pacman -Qtdq)
        if [ -n "$orphans" ]; then
            print_warning "Found orphaned packages. Use 'sudo pacman -Rns $(pacman -Qtdq)' to remove them."
        else
            print_success "No orphaned packages found."
        fi
    fi
    
    # Clean home directory
    print_info "Cleaning home directory..."
    rm -rf "$HOME"/.cache/thumbnails/* 2>/dev/null
    rm -rf "$HOME"/.local/share/Trash/* 2>/dev/null
    print_success "Home directory cleanup complete."
    
    # Clean system logs
    print_info "Cleaning system logs..."
    if command -v journalctl &>/dev/null; then
        sudo journalctl --vacuum-time=7d
    else
        print_warning "journalctl not found. Skipping log cleanup."
    fi
    
    print_success "System cleanup completed."
    return 0
}
