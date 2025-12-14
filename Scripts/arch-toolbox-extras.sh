#!/bin/bash

# Gaming optimization functions
optimize_gaming() {
    print_header "Gaming Optimization"
    
    # Install gaming packages
    print_info "Installing gaming packages..."
    sudo pacman -S --noconfirm \
        gamemode \
        lib32-gamemode \
        mangohud \
        lib32-mangohud \
        steam \
        wine \
        wine-mono \
        wine-gecko \
        winetricks \
        lutris \
        vulkan-icd-loader \
        lib32-vulkan-icd-loader \
        vulkan-tools \
        proton-ge-custom

    # Configure Gamemode
    print_info "Configuring Gamemode..."
    sudo systemctl enable --now gamemoded
    
    # Configure GPU settings
    local gpu_type=$(detect_gpu)
    case $gpu_type in
        "nvidia")
            print_info "Configuring NVIDIA settings..."
            sudo pacman -S --noconfirm nvidia-settings
            # Enable performance mode
            sudo nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1"
            # Enable ForceFullCompositionPipeline
            nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 { ForceFullCompositionPipeline = On }"
            ;;
        "amd")
            print_info "Configuring AMD settings..."
            echo "AMD_VULKAN_ICD=RADV" | sudo tee -a /etc/environment
            # Set performance mode
            echo "performance" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
            ;;
    esac
    
    # Configure CPU governor for gaming
    print_info "Configuring CPU settings..."
    sudo tee /etc/gamemode.ini > /dev/null <<EOL
[general]
renice=10
softrealtime=auto
inhibit_screensaver=1

[cpu]
governor=performance
frequency_percent=100

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=auto
amd_performance_level=high
EOL

    # Install Proton-GE
    print_info "Installing Proton-GE..."
    mkdir -p ~/.steam/root/compatibilitytools.d/
    latest_proton=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep "browser_download_url.*tar.gz" | cut -d : -f 2,3 | tr -d \")
    wget "$latest_proton" -O /tmp/proton.tar.gz
    tar -xzf /tmp/proton.tar.gz -C ~/.steam/root/compatibilitytools.d/
    rm /tmp/proton.tar.gz

    print_success "Gaming optimization complete"
}

# Development environment setup
setup_dev_environment() {
    print_header "Development Environment Setup"
    
    while true; do
        echo -e "\n${CYAN}Development Environment Options:${NC}"
        echo -e "${CYAN}1${NC}) Install base development tools"
        echo -e "${CYAN}2${NC}) Setup Python development"
        echo -e "${CYAN}3${NC}) Setup Node.js development"
        echo -e "${CYAN}4${NC}) Setup Rust development"
        echo -e "${CYAN}5${NC}) Setup Go development"
        echo -e "${CYAN}6${NC}) Setup Docker environment"
        echo -e "${CYAN}7${NC}) Setup VSCode with extensions"
        echo -e "${CYAN}8${NC}) Setup Git configuration"
        echo -e "${CYAN}9${NC}) Return to main menu"
        
        read -rp "Enter your choice: " dev_choice
        case $dev_choice in
            1)
                print_info "Installing base development tools..."
                sudo pacman -S --noconfirm \
                    base-devel \
                    git \
                    cmake \
                    ninja \
                    gdb \
                    lldb \
                    clang \
                    llvm \
                    make \
                    autoconf \
                    automake \
                    pkg-config
                ;;
            2)
                print_info "Setting up Python development environment..."
                sudo pacman -S --noconfirm \
                    python \
                    python-pip \
                    python-virtualenv \
                    python-poetry \
                    pyenv \
                    python-pylint \
                    python-black \
                    python-pytest
                ;;
            3)
                print_info "Setting up Node.js development environment..."
                sudo pacman -S --noconfirm nodejs npm
                # Install nvm for Node.js version management
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
                # Install global npm packages
                npm install -g yarn typescript ts-node nodemon eslint prettier
                ;;
            4)
                print_info "Setting up Rust development environment..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                source $HOME/.cargo/env
                rustup component add rls rust-analysis rust-src
                rustup toolchain install nightly
                cargo install cargo-edit cargo-watch cargo-audit
                ;;
            5)
                print_info "Setting up Go development environment..."
                sudo pacman -S --noconfirm go
                # Set up Go workspace
                mkdir -p ~/go/{bin,src,pkg}
                echo 'export GOPATH=$HOME/go' >> ~/.zshrc
                echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
                # Install common Go tools
                go install golang.org/x/tools/gopls@latest
                go install golang.org/x/tools/cmd/goimports@latest
                ;;
            6)
                print_info "Setting up Docker environment..."
                sudo pacman -S --noconfirm docker docker-compose
                sudo systemctl enable --now docker
                sudo usermod -aG docker $USER
                # Install Docker tools
                sudo pacman -S --noconfirm lazydocker ctop
                ;;
            7)
                print_info "Setting up VSCode with extensions..."
                sudo pacman -S --noconfirm code
                # Install popular extensions
                code --install-extension ms-python.python
                code --install-extension dbaeumer.vscode-eslint
                code --install-extension esbenp.prettier-vscode
                code --install-extension rust-lang.rust-analyzer
                code --install-extension golang.go
                code --install-extension ms-azuretools.vscode-docker
                code --install-extension github.copilot
                ;;
            8)
                print_info "Setting up Git configuration..."
                read -rp "Enter your Git username: " git_username
                read -rp "Enter your Git email: " git_email
                git config --global user.name "$git_username"
                git config --global user.email "$git_email"
                git config --global core.editor "nvim"
                git config --global init.defaultBranch "main"
                # Install Git tools
                sudo pacman -S --noconfirm \
                    git-delta \
                    lazygit \
                    github-cli \
                    git-lfs
                ;;
            9) break ;;
            *) print_error "Invalid choice" ;;
        esac
    done
}

# Advanced Hyprland customization
customize_hyprland_advanced() {
    print_header "Advanced Hyprland Customization"
    
    while true; do
        echo -e "\n${CYAN}Advanced Customization Options:${NC}"
        echo -e "${CYAN}1${NC}) Install and configure themes"
        echo -e "${CYAN}2${NC}) Configure animations and effects"
        echo -e "${CYAN}3${NC}) Configure workspaces and layouts"
        echo -e "${CYAN}4${NC}) Configure gestures and input"
        echo -e "${CYAN}5${NC}) Configure autostart applications"
        echo -e "${CYAN}6${NC}) Configure Waybar advanced"
        echo -e "${CYAN}7${NC}) Configure window rules"
        echo -e "${CYAN}8${NC}) Configure keybindings"
        echo -e "${CYAN}9${NC}) Return to main menu"
        
        read -rp "Enter your choice: " custom_choice
        case $custom_choice in
            1)
                print_info "Installing and configuring themes..."
                yay -S --noconfirm \
                    catppuccin-gtk-theme-mocha \
                    catppuccin-cursors-mocha \
                    papirus-icon-theme \
                    nwg-look \
                    qt5ct \
                    kvantum
                ;;
            2)
                print_info "Configuring animations and effects..."
                mkdir -p ~/.config/hypr
                cp /etc/hypr/hyprland.conf ~/.config/hypr/
                # Add custom animations
                cat >> ~/.config/hypr/hyprland.conf <<EOL
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}
EOL
                ;;
            3)
                print_info "Configuring workspaces and layouts..."
                # Add workspace configuration
                cat >> ~/.config/hypr/hyprland.conf <<EOL
workspace = 1, monitor:DP-1, default:true
workspace = 2, monitor:DP-1
workspace = 3, monitor:DP-1
workspace = 4, monitor:HDMI-A-1, default:true
workspace = 5, monitor:HDMI-A-1
EOL
                ;;
            4)
                print_info "Configuring gestures and input..."
                # Add input configuration
                cat >> ~/.config/hypr/hyprland.conf <<EOL
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
    }
    sensitivity = 0
    accel_profile = flat
}
EOL
                ;;
            5)
                print_info "Configuring autostart applications..."
                mkdir -p ~/.config/hypr/autostart
                # Create autostart script
                cat > ~/.config/hypr/autostart/autostart.sh <<EOL
#!/bin/bash
waybar &
dunst &
nm-applet --indicator &
blueman-applet &
EOL
                chmod +x ~/.config/hypr/autostart/autostart.sh
                ;;
            6)
                print_info "Configuring Waybar advanced..."
                mkdir -p ~/.config/waybar
                # Install additional modules
                yay -S --noconfirm \
                    waybar-module-pacman-updates-git \
                    waybar-module-weather-git
                ;;
            7)
                print_info "Configuring window rules..."
                # Add window rules
                cat >> ~/.config/hypr/hyprland.conf <<EOL
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$
windowrule = workspace 2, ^(firefox)$
windowrule = workspace 3, ^(code)$
EOL
                ;;
            8)
                print_info "Configuring keybindings..."
                # Add custom keybindings
                cat >> ~/.config/hypr/hyprland.conf <<EOL
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER SHIFT, Q, exit,
bind = SUPER, Space, exec, wofi --show drun
EOL
                ;;
            9) break ;;
            *) print_error "Invalid choice" ;;
        esac
    done
}

# Validate GPU settings
validate_gpu_settings() {
    local gpu_type=$1
    
    case $gpu_type in
        "nvidia")
            # Check NVIDIA driver installation
            if ! lsmod | grep -q "nvidia"; then
                print_error "NVIDIA driver not loaded"
                return 1
            fi
            # Verify nvidia-settings
            if ! command -v nvidia-settings >/dev/null; then
                print_error "nvidia-settings not installed"
                return 1
            fi
            # Check power management
            if ! nvidia-smi -q | grep -q "Power Management.*Enabled"; then
                print_warning "NVIDIA power management not enabled"
            fi
            ;;
        "amd")
            # Check AMD driver
            if ! lsmod | grep -q "amdgpu"; then
                print_error "AMD GPU driver not loaded"
                return 1
            fi
            # Verify vulkan support
            if ! vulkaninfo 2>/dev/null | grep -q "AMD"; then
                print_warning "Vulkan support may not be properly configured for AMD"
            fi
            ;;
        "intel")
            # Check Intel driver
            if ! lsmod | grep -q "i915"; then
                print_error "Intel GPU driver not loaded"
                return 1
            fi
            # Verify vulkan support
            if ! vulkaninfo 2>/dev/null | grep -q "Intel"; then
                print_warning "Vulkan support may not be properly configured for Intel"
            fi
            ;;
        *)
            print_error "Unsupported GPU type: $gpu_type"
            return 1
            ;;
    esac
    
    return 0
}

# Restore gaming optimizations
restore_gaming_optimizations() {
    print_header "Restore Gaming Optimizations"
    
    # Stop and disable Gamemode
    print_info "Restoring Gamemode settings..."
    sudo systemctl stop gamemoded
    sudo systemctl disable gamemoded
    
    # Restore GPU settings
    local gpu_type=$(detect_gpu)
    print_info "Restoring GPU settings for $gpu_type..."
    
    case $gpu_type in
        "nvidia")
            # Reset NVIDIA settings
            sudo nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=0"  # Auto mode
            nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0"
            ;;
        "amd")
            # Reset AMD settings
            sudo sed -i '/AMD_VULKAN_ICD=RADV/d' /etc/environment
            echo "auto" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
            ;;
    esac
    
    # Restore CPU governor
    print_info "Restoring CPU governor..."
    echo "ondemand" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    
    # Remove custom gamemode config
    if [ -f /etc/gamemode.ini ]; then
        print_info "Removing custom Gamemode configuration..."
        sudo rm /etc/gamemode.ini
    fi
    
    # Remove Proton-GE
    if [ -d ~/.steam/root/compatibilitytools.d ]; then
        print_info "Removing Proton-GE..."
        rm -rf ~/.steam/root/compatibilitytools.d/GE-Proton*
    fi
    
    print_success "Gaming optimizations restored to default settings"
}

# Export functions
export -f optimize_gaming
export -f setup_dev_environment
export -f customize_hyprland_advanced
export -f validate_gpu_settings
export -f restore_gaming_optimizations 