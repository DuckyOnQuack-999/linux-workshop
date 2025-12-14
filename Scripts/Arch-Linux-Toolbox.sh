# Hardware Management Functions
manage_hardware() {
    print_section "Hardware Management"
    
    echo "1. CPU Management"
    echo "2. GPU Management"
    echo "3. Storage Management"
    echo "4. Memory Management"
    echo "5. Power Management"
    echo "6. Input Devices"
    echo "7. Audio Devices"
    echo "8. Bluetooth Devices"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1) manage_cpu ;;
        2) manage_gpu ;;
        3) manage_storage ;;
        4) manage_memory ;;
        5) manage_power ;;
        6) manage_input_devices ;;
        7) manage_audio ;;
        8) manage_bluetooth ;;
        0) return ;;
        *) print_error "Invalid option" ;;
    esac
}

manage_cpu() {
    print_section "CPU Management"
    
    if ! check_command cpupower; then
        if confirm_action "cpupower not found. Install it?"; then
            sudo pacman -S cpupower
        else
            return
        fi
    fi
    
    echo "1. Show CPU Information"
    echo "2. Set CPU Governor"
    echo "3. Set CPU Frequency"
    echo "4. Show Temperature"
    echo "5. CPU Stress Test"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            print_info "CPU Information:"
            lscpu
            echo
            print_info "Current CPU Governor:"
            cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
            echo
            print_info "Current CPU Frequency:"
            cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq
            ;;
        2)
            print_info "Available governors:"
            cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
            read -rp "Enter governor name: " governor
            if [ -n "$governor" ]; then
                sudo cpupower frequency-set -g "$governor"
            fi
            ;;
        3)
            print_info "Frequency limits (kHz):"
            echo "Min: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)"
            echo "Max: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)"
            read -rp "Enter frequency in kHz (or 'min'/'max'): " freq
            if [ -n "$freq" ]; then
                sudo cpupower frequency-set -f "${freq}kHz"
            fi
            ;;
        4)
            if ! check_command sensors; then
                if confirm_action "lm_sensors not found. Install it?"; then
                    sudo pacman -S lm_sensors
                    sudo sensors-detect --auto
                else
                    return
                fi
            fi
            sensors | grep "Core"
            ;;
        5)
            if ! check_command stress-ng; then
                if confirm_action "stress-ng not found. Install it?"; then
                    sudo pacman -S stress-ng
                else
                    return
                fi
            fi
            read -rp "Enter test duration in seconds (default: 60): " duration
            duration=${duration:-60}
            stress-ng --cpu $(nproc) --timeout "$duration"s
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_gpu() {
    print_section "GPU Management"
    
    # Detect available GPUs
    if lspci | grep -i "vga" | grep -i "nvidia" >/dev/null; then
        has_nvidia=true
    fi
    if lspci | grep -i "vga" | grep -i "amd" >/dev/null; then
        has_amd=true
    fi
    if lspci | grep -i "vga" | grep -i "intel" >/dev/null; then
        has_intel=true
    fi
    
    echo "1. Show GPU Information"
    echo "2. Install/Update GPU Drivers"
    echo "3. Configure GPU Settings"
    echo "4. Power Management"
    echo "5. Monitor Configuration"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            print_info "GPU Information:"
            lspci | grep -i "vga"
            if [ "$has_nvidia" = true ]; then
                if check_command nvidia-smi; then
                    nvidia-smi
                fi
            fi
            if [ "$has_amd" = true ]; then
                if check_command radeontop; then
                    radeontop -d-
                fi
            fi
            ;;
        2)
            if [ "$has_nvidia" = true ]; then
                if confirm_action "Install NVIDIA drivers?"; then
                    sudo pacman -S nvidia nvidia-utils nvidia-settings
                fi
            fi
            if [ "$has_amd" = true ]; then
                if confirm_action "Install AMD drivers?"; then
                    sudo pacman -S xf86-video-amdgpu vulkan-radeon
                fi
            fi
            if [ "$has_intel" = true ]; then
                if confirm_action "Install Intel drivers?"; then
                    sudo pacman -S xf86-video-intel vulkan-intel
                fi
            fi
            ;;
        3)
            if [ "$has_nvidia" = true ] && check_command nvidia-settings; then
                nvidia-settings
            elif [ "$has_amd" = true ]; then
                print_info "AMD GPU settings can be configured through /etc/X11/xorg.conf.d/"
                if confirm_action "Edit AMD GPU configuration?"; then
                    sudo $EDITOR /etc/X11/xorg.conf.d/20-amdgpu.conf
                fi
            fi
            ;;
        4)
            if [ "$has_nvidia" = true ]; then
                echo "1. Performance Mode"
                echo "2. Power Saving Mode"
                read -rp "Select mode: " mode
                case $mode in
                    1) sudo nvidia-smi -pm 1 ;;
                    2) sudo nvidia-smi -pm 0 ;;
                esac
            fi
            if [ "$has_amd" = true ]; then
                print_info "AMD power management is handled through the kernel"
                cat /sys/class/drm/card0/device/power_dpm_state
            fi
            ;;
        5)
            if ! check_command xrandr; then
                print_error "xrandr not found"
                return
            fi
            print_info "Available monitors:"
            xrandr --listmonitors
            read -rp "Enter monitor name: " monitor
            if [ -n "$monitor" ]; then
                echo "1. Set Resolution"
                echo "2. Set Refresh Rate"
                echo "3. Set Primary"
                echo "4. Enable Monitor"
                echo "5. Disable Monitor"
                read -rp "Select option: " suboption
                case $suboption in
                    1)
                        print_info "Available resolutions:"
                        xrandr | grep "$monitor" -A 10 | grep "^[[:space:]]*[0-9]"
                        read -rp "Enter resolution (e.g., 1920x1080): " res
                        if [ -n "$res" ]; then
                            xrandr --output "$monitor" --mode "$res"
                        fi
                        ;;
                    2)
                        read -rp "Enter refresh rate (e.g., 60): " rate
                        if [ -n "$rate" ]; then
                            xrandr --output "$monitor" --rate "$rate"
                        fi
                        ;;
                    3)
                        xrandr --output "$monitor" --primary
                        ;;
                    4)
                        xrandr --output "$monitor" --auto
                        ;;
                    5)
                        xrandr --output "$monitor" --off
                        ;;
                esac
            fi
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_storage() {
    print_section "Storage Management"
    
    echo "1. Show Storage Information"
    echo "2. Check Disk Health"
    echo "3. Manage Partitions"
    echo "4. Mount/Unmount"
    echo "5. SMART Data"
    echo "6. Filesystem Check"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            print_info "Storage Information:"
            df -h
            echo
            print_info "Block Devices:"
            lsblk -f
            ;;
        2)
            if ! check_command smartctl; then
                if confirm_action "smartmontools not found. Install it?"; then
                    sudo pacman -S smartmontools
                else
                    return
                fi
            fi
            print_info "Available disks:"
            lsblk -d
            read -rp "Enter disk name (e.g., sda): " disk
            if [ -n "$disk" ]; then
                sudo smartctl -H "/dev/$disk"
            fi
            ;;
        3)
            if ! check_command gparted; then
                if confirm_action "GParted not found. Install it?"; then
                    sudo pacman -S gparted
                else
                    return
                fi
            fi
            sudo gparted
            ;;
        4)
            print_info "Available partitions:"
            lsblk
            read -rp "Enter partition (e.g., sda1): " part
            if [ -n "$part" ]; then
                echo "1. Mount"
                echo "2. Unmount"
                read -rp "Select option: " suboption
                case $suboption in
                    1)
                        read -rp "Enter mount point: " mpoint
                        if [ -n "$mpoint" ]; then
                            sudo mount "/dev/$part" "$mpoint"
                        fi
                        ;;
                    2)
                        sudo umount "/dev/$part"
                        ;;
                esac
            fi
            ;;
        5)
            if ! check_command smartctl; then
                if confirm_action "smartmontools not found. Install it?"; then
                    sudo pacman -S smartmontools
                else
                    return
                fi
            fi
            print_info "Available disks:"
            lsblk -d
            read -rp "Enter disk name (e.g., sda): " disk
            if [ -n "$disk" ]; then
                sudo smartctl -a "/dev/$disk"
            fi
            ;;
        6)
            print_info "Available partitions:"
            lsblk -f
            read -rp "Enter partition (e.g., sda1): " part
            if [ -n "$part" ]; then
                if confirm_action "This will check filesystem on /dev/$part. Continue?"; then
                    sudo fsck -f "/dev/$part"
                fi
            fi
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_memory() {
    print_section "Memory Management"
    
    echo "1. Show Memory Information"
    echo "2. Manage Swap"
    echo "3. Clear Cache"
    echo "4. Memory Test"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            print_info "Memory Information:"
            free -h
            echo
            print_info "Detailed Memory Info:"
            cat /proc/meminfo
            ;;
        2)
            echo "1. Show Swap Info"
            echo "2. Create Swap File"
            echo "3. Enable Swap"
            echo "4. Disable Swap"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    swapon --show
                    ;;
                2)
                    read -rp "Enter size in GB: " size
                    if [[ "$size" =~ ^[0-9]+$ ]]; then
                        sudo fallocate -l "${size}G" /swapfile
                        sudo chmod 600 /swapfile
                        sudo mkswap /swapfile
                        sudo swapon /swapfile
                        echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
                    fi
                    ;;
                3)
                    sudo swapon --all
                    ;;
                4)
                    sudo swapoff --all
                    ;;
            esac
            ;;
        3)
            echo "1. Clear PageCache"
            echo "2. Clear Dentries and Inodes"
            echo "3. Clear All Caches"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    sudo sync; sudo echo 1 > /proc/sys/vm/drop_caches
                    ;;
                2)
                    sudo sync; sudo echo 2 > /proc/sys/vm/drop_caches
                    ;;
                3)
                    sudo sync; sudo echo 3 > /proc/sys/vm/drop_caches
                    ;;
            esac
            ;;
        4)
            if ! check_command memtest86+; then
                if confirm_action "memtest86+ not found. Install it?"; then
                    sudo pacman -S memtest86+
                else
                    return
                fi
            fi
            print_info "Memtest86+ will be available in your boot menu"
            print_info "Please reboot and select memtest86+ to run the memory test"
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_power() {
    print_section "Power Management"
    
    echo "1. Show Power Information"
    echo "2. Power Profiles"
    echo "3. Battery Management"
    echo "4. Sleep Settings"
    echo "5. CPU Frequency Scaling"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            if check_command upower; then
                upower -i $(upower -e | grep BAT)
            else
                acpi -V
            fi
            ;;
        2)
            if ! check_command tlp; then
                if confirm_action "TLP not found. Install it?"; then
                    sudo pacman -S tlp
                    sudo systemctl enable tlp
                    sudo systemctl start tlp
                else
                    return
                fi
            fi
            echo "1. Performance"
            echo "2. Balanced"
            echo "3. Power Saver"
            read -rp "Select profile: " profile
            case $profile in
                1) sudo tlp start performance ;;
                2) sudo tlp start balanced ;;
                3) sudo tlp start bat ;;
            esac
            ;;
        3)
            if check_command tlp; then
                echo "1. Show Battery Info"
                echo "2. Recalibrate Battery"
                echo "3. Battery Care Settings"
                read -rp "Select option: " suboption
                case $suboption in
                    1)
                        sudo tlp-stat -b
                        ;;
                    2)
                        if confirm_action "This will recalibrate your battery. Continue?"; then
                            sudo tlp recalibrate BAT0
                        fi
                        ;;
                    3)
                        sudo $EDITOR /etc/tlp.conf
                        ;;
                esac
            else
                print_error "TLP not installed"
            fi
            ;;
        4)
            echo "1. Show Sleep Settings"
            echo "2. Configure Sleep"
            echo "3. Configure Hibernate"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    systemctl status sleep.target
                    ;;
                2)
                    sudo $EDITOR /etc/systemd/sleep.conf
                    ;;
                3)
                    if [ -f /etc/default/grub ]; then
                        sudo $EDITOR /etc/default/grub
                        if confirm_action "Update GRUB configuration?"; then
                            sudo grub-mkconfig -o /boot/grub/grub.cfg
                        fi
                    fi
                    ;;
            esac
            ;;
        5)
            manage_cpu
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_input_devices() {
    print_section "Input Device Management"
    
    echo "1. List Input Devices"
    echo "2. Configure Keyboard"
    echo "3. Configure Mouse"
    echo "4. Configure Touchpad"
    echo "5. Configure Tablet"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            print_info "Input Devices:"
            if check_command libinput; then
                libinput list-devices
            else
                xinput list
            fi
            ;;
        2)
            echo "1. Set Keyboard Layout"
            echo "2. Set Keyboard Model"
            echo "3. Set Keyboard Options"
            echo "4. Set Repeat Rate"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    print_info "Available layouts:"
                    localectl list-keymaps
                    read -rp "Enter layout (e.g., us): " layout
                    if [ -n "$layout" ]; then
                        sudo localectl set-keymap "$layout"
                    fi
                    ;;
                2)
                    print_info "Available models:"
                    localectl list-x11-keymap-models
                    read -rp "Enter model: " model
                    if [ -n "$model" ]; then
                        setxkbmap -model "$model"
                    fi
                    ;;
                3)
                    print_info "Available options:"
                    localectl list-x11-keymap-options
                    read -rp "Enter option: " option
                    if [ -n "$option" ]; then
                        setxkbmap -option "$option"
                    fi
                    ;;
                4)
                    read -rp "Enter delay (ms): " delay
                    read -rp "Enter rate (Hz): " rate
                    if [ -n "$delay" ] && [ -n "$rate" ]; then
                        xset r rate "$delay" "$rate"
                    fi
                    ;;
            esac
            ;;
        3)
            if ! check_command xinput; then
                if confirm_action "xinput not found. Install it?"; then
                    sudo pacman -S xorg-xinput
                else
                    return
                fi
            fi
            print_info "Mouse devices:"
            xinput list | grep -i "mouse"
            read -rp "Enter device ID: " id
            if [ -n "$id" ]; then
                echo "1. Set Speed"
                echo "2. Enable/Disable Device"
                echo "3. Configure Buttons"
                read -rp "Select option: " suboption
                case $suboption in
                    1)
                        read -rp "Enter speed (-1 to 1): " speed
                        if [ -n "$speed" ]; then
                            xinput set-prop "$id" "libinput Accel Speed" "$speed"
                        fi
                        ;;
                    2)
                        echo "1. Enable"
                        echo "2. Disable"
                        read -rp "Select option: " state
                        case $state in
                            1) xinput enable "$id" ;;
                            2) xinput disable "$id" ;;
                        esac
                        ;;
                    3)
                        print_info "Current button mapping:"
                        xinput get-button-map "$id"
                        read -rp "Enter new button map (e.g., 1 2 3): " map
                        if [ -n "$map" ]; then
                            xinput set-button-map "$id" $map
                        fi
                        ;;
                esac
            fi
            ;;
        4)
            if ! check_command xinput; then
                if confirm_action "xinput not found. Install it?"; then
                    sudo pacman -S xorg-xinput
                else
                    return
                fi
            fi
            print_info "Touchpad devices:"
            xinput list | grep -i "touchpad"
            read -rp "Enter device ID: " id
            if [ -n "$id" ]; then
                echo "1. Enable/Disable Tapping"
                echo "2. Enable/Disable Natural Scrolling"
                echo "3. Set Speed"
                echo "4. Enable/Disable While Typing"
                read -rp "Select option: " suboption
                case $suboption in
                    1)
                        echo "1. Enable"
                        echo "2. Disable"
                        read -rp "Select option: " state
                        case $state in
                            1) xinput set-prop "$id" "libinput Tapping Enabled" 1 ;;
                            2) xinput set-prop "$id" "libinput Tapping Enabled" 0 ;;
                        esac
                        ;;
                    2)
                        echo "1. Enable"
                        echo "2. Disable"
                        read -rp "Select option: " state
                        case $state in
                            1) xinput set-prop "$id" "libinput Natural Scrolling Enabled" 1 ;;
                            2) xinput set-prop "$id" "libinput Natural Scrolling Enabled" 0 ;;
                        esac
                        ;;
                    3)
                        read -rp "Enter speed (-1 to 1): " speed
                        if [ -n "$speed" ]; then
                            xinput set-prop "$id" "libinput Accel Speed" "$speed"
                        fi
                        ;;
                    4)
                        echo "1. Enable"
                        echo "2. Disable"
                        read -rp "Select option: " state
                        case $state in
                            1) xinput set-prop "$id" "libinput Disable While Typing Enabled" 1 ;;
                            2) xinput set-prop "$id" "libinput Disable While Typing Enabled" 0 ;;
                        esac
                        ;;
                esac
            fi
            ;;
        5)
            if ! check_command xsetwacom; then
                if confirm_action "xf86-input-wacom not found. Install it?"; then
                    sudo pacman -S xf86-input-wacom
                else
                    return
                fi
            fi
            print_info "Tablet devices:"
            xsetwacom list devices
            read -rp "Enter device name: " device
            if [ -n "$device" ]; then
                echo "1. Set Mode (Absolute/Relative)"
                echo "2. Set Button Mapping"
                echo "3. Set Area"
                echo "4. Calibrate"
                read -rp "Select option: " suboption
                case $suboption in
                    1)
                        echo "1. Absolute"
                        echo "2. Relative"
                        read -rp "Select mode: " mode
                        case $mode in
                            1) xsetwacom set "$device" Mode "Absolute" ;;
                            2) xsetwacom set "$device" Mode "Relative" ;;
                        esac
                        ;;
                    2)
                        read -rp "Enter button number: " button
                        read -rp "Enter action (e.g., 'key ctrl z'): " action
                        if [ -n "$button" ] && [ -n "$action" ]; then
                            xsetwacom set "$device" Button "$button" "$action"
                        fi
                        ;;
                    3)
                        read -rp "Enter area (e.g., '0 0 15200 9500'): " area
                        if [ -n "$area" ]; then
                            xsetwacom set "$device" Area $area
                        fi
                        ;;
                    4)
                        xsetwacom set "$device" ResetArea
                        print_info "Touch the corners of your screen when prompted"
                        xinput_calibrator --device "$device"
                        ;;
                esac
            fi
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_audio() {
    print_section "Audio Management"
    
    if ! check_command pulseaudio && ! check_command pipewire; then
        if confirm_action "No audio server found. Install PipeWire?"; then
            sudo pacman -S pipewire pipewire-pulse pipewire-alsa pipewire-jack
            systemctl --user enable pipewire pipewire-pulse
            systemctl --user start pipewire pipewire-pulse
        else
            return
        fi
    fi
    
    echo "1. Show Audio Devices"
    echo "2. Volume Control"
    echo "3. Default Device"
    echo "4. Audio Settings"
    echo "5. Audio Server"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            if check_command pactl; then
                print_info "Output devices:"
                pactl list sinks
                echo
                print_info "Input devices:"
                pactl list sources
            else
                print_info "Audio devices:"
                aplay -l
                echo
                print_info "Recording devices:"
                arecord -l
            fi
            ;;
        2)
            if ! check_command pamixer; then
                if confirm_action "pamixer not found. Install it?"; then
                    sudo pacman -S pamixer
                else
                    return
                fi
            fi
            echo "1. Set Master Volume"
            echo "2. Toggle Mute"
            echo "3. Increase Volume"
            echo "4. Decrease Volume"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    read -rp "Enter volume (0-100): " vol
                    if [[ "$vol" =~ ^[0-9]+$ ]] && [ "$vol" -le 100 ]; then
                        pamixer --set-volume "$vol"
                    fi
                    ;;
                2)
                    pamixer -t
                    ;;
                3)
                    pamixer -i 5
                    ;;
                4)
                    pamixer -d 5
                    ;;
            esac
            ;;
        3)
            if check_command pactl; then
                print_info "Available output devices:"
                pactl list short sinks
                read -rp "Enter device name: " device
                if [ -n "$device" ]; then
                    pactl set-default-sink "$device"
                fi
            fi
            ;;
        4)
            if check_command pavucontrol; then
                pavucontrol
            else
                if confirm_action "pavucontrol not found. Install it?"; then
                    sudo pacman -S pavucontrol
                    pavucontrol
                fi
            fi
            ;;
        5)
            echo "1. Restart Audio Server"
            echo "2. Switch Server"
            echo "3. Show Status"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    systemctl --user restart pipewire pipewire-pulse
                    ;;
                2)
                    echo "1. PipeWire"
                    echo "2. PulseAudio"
                    read -rp "Select server: " server
                    case $server in
                        1)
                            sudo pacman -S pipewire pipewire-pulse
                            systemctl --user enable pipewire pipewire-pulse
                            systemctl --user start pipewire pipewire-pulse
                            ;;
                        2)
                            sudo pacman -S pulseaudio
                            systemctl --user enable pulseaudio
                            systemctl --user start pulseaudio
                            ;;
                    esac
                    ;;
                3)
                    systemctl --user status pipewire pipewire-pulse
                    ;;
            esac
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_bluetooth() {
    print_section "Bluetooth Management"
    
    if ! check_command bluetoothctl; then
        if confirm_action "bluetooth-utils not found. Install it?"; then
            sudo pacman -S bluez bluez-utils
            sudo systemctl enable bluetooth
            sudo systemctl start bluetooth
        else
            return
        fi
    fi
    
    echo "1. Show Devices"
    echo "2. Scan for Devices"
    echo "3. Pair Device"
    echo "4. Connect Device"
    echo "5. Remove Device"
    echo "6. Toggle Bluetooth"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            print_info "Paired devices:"
            bluetoothctl paired-devices
            echo
            print_info "Connected devices:"
            bluetoothctl devices Connected
            ;;
        2)
            print_info "Scanning for devices... (press Ctrl+C to stop)"
            bluetoothctl scan on
            ;;
        3)
            print_info "Available devices:"
            bluetoothctl devices
            read -rp "Enter device MAC address: " mac
            if [ -n "$mac" ]; then
                bluetoothctl pair "$mac"
            fi
            ;;
        4)
            print_info "Paired devices:"
            bluetoothctl paired-devices
            read -rp "Enter device MAC address: " mac
            if [ -n "$mac" ]; then
                bluetoothctl connect "$mac"
            fi
            ;;
        5)
            print_info "Paired devices:"
            bluetoothctl paired-devices
            read -rp "Enter device MAC address: " mac
            if [ -n "$mac" ]; then
                bluetoothctl remove "$mac"
            fi
            ;;
        6)
            echo "1. Enable"
            echo "2. Disable"
            read -rp "Select option: " state
            case $state in
                1)
                    bluetoothctl power on
                    ;;
                2)
                    bluetoothctl power off
                    ;;
            esac
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_gaming() {
    print_section "Gaming Optimization"
    
    echo "1. Install Gaming Tools"
    echo "2. GPU Optimization"
    echo "3. CPU Optimization"
    echo "4. Memory Optimization"
    echo "5. Storage Optimization"
    echo "6. Network Optimization"
    echo "7. Manage Steam"
    echo "8. Manage Wine"
    echo "9. Manage Lutris"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            echo "1. Install Steam"
            echo "2. Install Wine"
            echo "3. Install Lutris"
            echo "4. Install ProtonGE"
            echo "5. Install GameMode"
            echo "6. Install MangoHud"
            echo "0. Back"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if confirm_action "Install Steam?"; then
                        sudo pacman -S steam
                    fi
                    ;;
                2)
                    if confirm_action "Install Wine?"; then
                        sudo pacman -S wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader
                    fi
                    ;;
                3)
                    if confirm_action "Install Lutris?"; then
                        sudo pacman -S lutris
                    fi
                    ;;
                4)
                    if ! check_command protonup; then
                        if confirm_action "ProtonUp-Qt not found. Install it?"; then
                            sudo pacman -S protonup-qt
                        else
                            return
                        fi
                    fi
                    protonup
                    ;;
                5)
                    if confirm_action "Install GameMode?"; then
                        sudo pacman -S gamemode lib32-gamemode
                        systemctl --user enable gamemoded
                        systemctl --user start gamemoded
                    fi
                    ;;
                6)
                    if confirm_action "Install MangoHud?"; then
                        sudo pacman -S mangohud lib32-mangohud
                    fi
                    ;;
                0)
                    return
                    ;;
            esac
            ;;
        2)
            echo "1. Enable GPU Performance Mode"
            echo "2. Configure GPU Settings"
            echo "3. Install Vulkan Support"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if lspci | grep -i "nvidia" >/dev/null; then
                        sudo nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1"
                        sudo nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=100"
                        sudo nvidia-settings -a "[gpu:0]/GPUMemoryTransferRateOffset[3]=200"
                    elif lspci | grep -i "amd" >/dev/null; then
                        echo "performance" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
                    fi
                    ;;
                2)
                    if lspci | grep -i "nvidia" >/dev/null; then
                        nvidia-settings
                    elif lspci | grep -i "amd" >/dev/null; then
                        if ! check_command corectrl; then
                            if confirm_action "CoreCtrl not found. Install it?"; then
                                sudo pacman -S corectrl
                            fi
                        fi
                        corectrl
                    fi
                    ;;
                3)
                    if confirm_action "Install Vulkan support?"; then
                        if lspci | grep -i "nvidia" >/dev/null; then
                            sudo pacman -S vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools
                        elif lspci | grep -i "amd" >/dev/null; then
                            sudo pacman -S vulkan-radeon lib32-vulkan-radeon vulkan-tools
                        elif lspci | grep -i "intel" >/dev/null; then
                            sudo pacman -S vulkan-intel lib32-vulkan-intel vulkan-tools
                        fi
                    fi
                    ;;
            esac
            ;;
        3)
            echo "1. Set CPU Governor"
            echo "2. Enable CPU Performance Mode"
            echo "3. Configure CPU Settings"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if ! check_command cpupower; then
                        sudo pacman -S cpupower
                    fi
                    sudo cpupower frequency-set -g performance
                    ;;
                2)
                    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
                    ;;
                3)
                    if ! check_command zenpower; then
                        if confirm_action "zenpower not found. Install it?"; then
                            yay -S zenpower-dkms
                            sudo modprobe zenpower
                        fi
                    fi
                    echo "1. Set CPU Frequency"
                    echo "2. Set CPU Voltage"
                    read -rp "Select option: " cpu_option
                    case $cpu_option in
                        1)
                            read -rp "Enter frequency in MHz: " freq
                            if [ -n "$freq" ]; then
                                echo "$freq" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq
                            fi
                            ;;
                        2)
                            if check_command ryzenadj; then
                                read -rp "Enter voltage offset (mV): " voltage
                                if [ -n "$voltage" ]; then
                                    sudo ryzenadj --stapm-limit="$voltage"
                                fi
                            else
                                print_error "ryzenadj not found"
                            fi
                            ;;
                    esac
                    ;;
            esac
            ;;
        4)
            echo "1. Clear Memory Cache"
            echo "2. Configure Swap"
            echo "3. Set Process Priority"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    sudo sync
                    sudo echo 3 > /proc/sys/vm/drop_caches
                    ;;
                2)
                    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-gaming.conf
                    echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.d/99-gaming.conf
                    sudo sysctl -p /etc/sysctl.d/99-gaming.conf
                    ;;
                3)
                    if ! check_command renice; then
                        sudo pacman -S util-linux
                    fi
                    ps aux | grep -i "steam\|lutris\|wine" | grep -v grep
                    read -rp "Enter PID to optimize: " pid
                    if [ -n "$pid" ]; then
                        sudo renice -n -5 -p "$pid"
                        sudo chrt -f -p 99 "$pid"
                    fi
                    ;;
            esac
            ;;
        5)
            echo "1. Enable TRIM"
            echo "2. Set I/O Scheduler"
            echo "3. Mount Options"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    sudo systemctl enable fstrim.timer
                    sudo systemctl start fstrim.timer
                    ;;
                2)
                    echo "deadline" | sudo tee /sys/block/sd*/queue/scheduler
                    ;;
                3)
                    if confirm_action "Add noatime mount option to improve disk performance?"; then
                        sudo sed -i 's/relatime/noatime/' /etc/fstab
                        sudo mount -o remount,noatime /
                    fi
                    ;;
            esac
            ;;
        6)
            echo "1. Optimize TCP Settings"
            echo "2. Configure Network Priority"
            echo "3. Enable BBR"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    echo "net.ipv4.tcp_fastopen=3" | sudo tee -a /etc/sysctl.d/99-gaming.conf
                    echo "net.ipv4.tcp_tw_reuse=1" | sudo tee -a /etc/sysctl.d/99-gaming.conf
                    echo "net.ipv4.tcp_mtu_probing=1" | sudo tee -a /etc/sysctl.d/99-gaming.conf
                    sudo sysctl -p /etc/sysctl.d/99-gaming.conf
                    ;;
                2)
                    if ! check_command wondershaper; then
                        if confirm_action "wondershaper not found. Install it?"; then
                            sudo pacman -S wondershaper
                        fi
                    fi
                    ip link show
                    read -rp "Enter interface name: " iface
                    if [ -n "$iface" ]; then
                        sudo wondershaper "$iface" 1000000 1000000
                    fi
                    ;;
                3)
                    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.d/99-gaming.conf
                    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.d/99-gaming.conf
                    sudo sysctl -p /etc/sysctl.d/99-gaming.conf
                    ;;
            esac
            ;;
        7)
            if ! check_command steam; then
                if confirm_action "Steam not found. Install it?"; then
                    sudo pacman -S steam
                else
                    return
                fi
            fi
            echo "1. Launch Steam"
            echo "2. Configure Steam"
            echo "3. Manage Proton"
            echo "4. Steam Tools"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    steam &
                    ;;
                2)
                    if [ -f ~/.local/share/Steam/config/config.vdf ]; then
                        $EDITOR ~/.local/share/Steam/config/config.vdf
                    fi
                    ;;
                3)
                    if ! check_command protonup; then
                        if confirm_action "ProtonUp-Qt not found. Install it?"; then
                            sudo pacman -S protonup-qt
                        else
                            return
                        fi
                    fi
                    protonup
                    ;;
                4)
                    echo "1. Install Steam Tweaks"
                    echo "2. Install ProtonGE"
                    echo "3. Install MangoHud"
                    read -rp "Select option: " tool
                    case $tool in
                        1)
                            if confirm_action "Install Steam Tweaks?"; then
                                yay -S steam-tweaks
                            fi
                            ;;
                        2)
                            if ! check_command protonup; then
                                if confirm_action "ProtonUp-Qt not found. Install it?"; then
                                    sudo pacman -S protonup-qt
                                fi
                            fi
                            protonup
                            ;;
                        3)
                            if confirm_action "Install MangoHud?"; then
                                sudo pacman -S mangohud lib32-mangohud
                            fi
                            ;;
                    esac
                    ;;
            esac
            ;;
        8)
            if ! check_command wine; then
                if confirm_action "Wine not found. Install it?"; then
                    sudo pacman -S wine-staging
                else
                    return
                fi
            fi
            echo "1. Configure Wine"
            echo "2. Install Components"
            echo "3. Manage Prefixes"
            echo "4. Wine Tools"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    winecfg
                    ;;
                2)
                    if ! check_command winetricks; then
                        sudo pacman -S winetricks
                    fi
                    winetricks
                    ;;
                3)
                    echo "1. Create Prefix"
                    echo "2. Delete Prefix"
                    echo "3. Configure Prefix"
                    read -rp "Select option: " prefix_option
                    case $prefix_option in
                        1)
                            read -rp "Enter prefix name: " prefix
                            if [ -n "$prefix" ]; then
                                WINEPREFIX="$HOME/.wine_$prefix" winecfg
                            fi
                            ;;
                        2)
                            read -rp "Enter prefix name: " prefix
                            if [ -n "$prefix" ] && [ -d "$HOME/.wine_$prefix" ]; then
                                rm -rf "$HOME/.wine_$prefix"
                            fi
                            ;;
                        3)
                            read -rp "Enter prefix name: " prefix
                            if [ -n "$prefix" ] && [ -d "$HOME/.wine_$prefix" ]; then
                                WINEPREFIX="$HOME/.wine_$prefix" winecfg
                            fi
                            ;;
                    esac
                    ;;
                4)
                    echo "1. Install DXVK"
                    echo "2. Install VKD3D"
                    echo "3. Install Dependencies"
                    read -rp "Select option: " tool
                    case $tool in
                        1)
                            if confirm_action "Install DXVK?"; then
                                sudo pacman -S dxvk-bin
                                setup_dxvk install
                            fi
                            ;;
                        2)
                            if confirm_action "Install VKD3D?"; then
                                sudo pacman -S vkd3d-proton
                            fi
                            ;;
                        3)
                            if confirm_action "Install Wine dependencies?"; then
                                sudo pacman -S giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader
                            fi
                            ;;
                    esac
                    ;;
            esac
            ;;
        9)
            if ! check_command lutris; then
                if confirm_action "Lutris not found. Install it?"; then
                    sudo pacman -S lutris
                else
                    return
                fi
            fi
            echo "1. Launch Lutris"
            echo "2. Configure Lutris"
            echo "3. Install Runners"
            echo "4. Lutris Tools"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    lutris &
                    ;;
                2)
                    if [ -f ~/.config/lutris/lutris.conf ]; then
                        $EDITOR ~/.config/lutris/lutris.conf
                    fi
                    ;;
                3)
                    echo "1. Install Wine Runner"
                    echo "2. Install Steam Runner"
                    echo "3. Install DOSBox Runner"
                    read -rp "Select option: " runner
                    case $runner in
                        1)
                            lutris -i wine
                            ;;
                        2)
                            lutris -i steam
                            ;;
                        3)
                            lutris -i dosbox
                            ;;
                    esac
                    ;;
                4)
                    echo "1. Install GameMode"
                    echo "2. Install MangoHud"
                    echo "3. Install Dependencies"
                    read -rp "Select option: " tool
                    case $tool in
                        1)
                            if confirm_action "Install GameMode?"; then
                                sudo pacman -S gamemode lib32-gamemode
                                systemctl --user enable gamemoded
                                systemctl --user start gamemoded
                            fi
                            ;;
                        2)
                            if confirm_action "Install MangoHud?"; then
                                sudo pacman -S mangohud lib32-mangohud
                            fi
                            ;;
                        3)
                            if confirm_action "Install Lutris dependencies?"; then
                                sudo pacman -S wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader
                            fi
                            ;;
                    esac
                    ;;
            esac
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_development() {
    print_section "Development Environment Management"
    
    echo "1. Install Development Tools"
    echo "2. Configure Git"
    echo "3. Setup Programming Languages"
    echo "4. Setup IDEs/Editors"
    echo "5. Setup Build Tools"
    echo "6. Setup Containers"
    echo "7. Setup Databases"
    echo "8. Setup Version Control"
    echo "9. Development Utils"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            echo "1. Base Development Tools"
            echo "2. Version Control Tools"
            echo "3. Build Tools"
            echo "4. Debugging Tools"
            echo "5. Documentation Tools"
            echo "0. Back"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if confirm_action "Install base development tools?"; then
                        sudo pacman -S base-devel cmake gcc gdb make automake autoconf
                    fi
                    ;;
                2)
                    if confirm_action "Install version control tools?"; then
                        sudo pacman -S git git-lfs mercurial subversion
                    fi
                    ;;
                3)
                    if confirm_action "Install build tools?"; then
                        sudo pacman -S ninja meson maven gradle ant
                    fi
                    ;;
                4)
                    if confirm_action "Install debugging tools?"; then
                        sudo pacman -S gdb lldb valgrind strace ltrace
                    fi
                    ;;
                5)
                    if confirm_action "Install documentation tools?"; then
                        sudo pacman -S doxygen graphviz plantuml
                    fi
                    ;;
                0)
                    return
                    ;;
            esac
            ;;
        2)
            echo "1. Configure User"
            echo "2. Configure SSH"
            echo "3. Configure GPG"
            echo "4. Configure Git Settings"
            echo "5. Configure Git Hooks"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    read -rp "Enter Git username: " username
                    read -rp "Enter Git email: " email
                    if [ -n "$username" ] && [ -n "$email" ]; then
                        git config --global user.name "$username"
                        git config --global user.email "$email"
                    fi
                    ;;
                2)
                    if ! [ -f ~/.ssh/id_ed25519 ]; then
                        read -rp "Enter email for SSH key: " email
                        if [ -n "$email" ]; then
                            ssh-keygen -t ed25519 -C "$email"
                            eval "$(ssh-agent -s)"
                            ssh-add ~/.ssh/id_ed25519
                            print_info "Public key:"
                            cat ~/.ssh/id_ed25519.pub
                        fi
                    fi
                    ;;
                3)
                    if ! check_command gpg; then
                        sudo pacman -S gnupg
                    fi
                    gpg --full-generate-key
                    gpg --list-secret-keys --keyid-format LONG
                    read -rp "Enter GPG key ID: " keyid
                    if [ -n "$keyid" ]; then
                        git config --global user.signingkey "$keyid"
                        git config --global commit.gpgsign true
                    fi
                    ;;
                4)
                    echo "core.editor=vim" >> ~/.gitconfig
                    echo "pull.rebase=true" >> ~/.gitconfig
                    echo "init.defaultBranch=main" >> ~/.gitconfig
                    echo "color.ui=auto" >> ~/.gitconfig
                    ;;
                5)
                    if [ ! -d ~/.git-templates ]; then
                        mkdir -p ~/.git-templates/hooks
                    fi
                    git config --global init.templatedir '~/.git-templates'
                    ;;
            esac
            ;;
        3)
            echo "1. Python Development"
            echo "2. Node.js Development"
            echo "3. Java Development"
            echo "4. C/C++ Development"
            echo "5. Go Development"
            echo "6. Rust Development"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    echo "1. Install Python"
                    echo "2. Setup Virtual Environments"
                    echo "3. Install Python Tools"
                    read -rp "Select option: " python_option
                    case $python_option in
                        1)
                            sudo pacman -S python python-pip
                            ;;
                        2)
                            sudo pacman -S python-virtualenv python-venv
                            mkdir -p ~/.virtualenvs
                            ;;
                        3)
                            pip install pylint autopep8 black mypy pytest
                            ;;
                    esac
                    ;;
                2)
                    echo "1. Install Node.js"
                    echo "2. Install Development Tools"
                    echo "3. Configure npm"
                    read -rp "Select option: " node_option
                    case $node_option in
                        1)
                            sudo pacman -S nodejs npm
                            ;;
                        2)
                            sudo npm install -g typescript ts-node eslint prettier
                            ;;
                        3)
                            mkdir -p ~/.npm-global
                            npm config set prefix '~/.npm-global'
                            echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
                            ;;
                    esac
                    ;;
                3)
                    echo "1. Install JDK"
                    echo "2. Install Build Tools"
                    echo "3. Setup Environment"
                    read -rp "Select option: " java_option
                    case $java_option in
                        1)
                            sudo pacman -S jdk-openjdk
                            ;;
                        2)
                            sudo pacman -S maven gradle
                            ;;
                        3)
                            echo 'export JAVA_HOME=/usr/lib/jvm/default' >> ~/.bashrc
                            ;;
                    esac
                    ;;
                4)
                    echo "1. Install Compilers"
                    echo "2. Install Build Tools"
                    echo "3. Install Debug Tools"
                    read -rp "Select option: " cpp_option
                    case $cpp_option in
                        1)
                            sudo pacman -S gcc clang
                            ;;
                        2)
                            sudo pacman -S cmake ninja meson
                            ;;
                        3)
                            sudo pacman -S gdb lldb valgrind
                            ;;
                    esac
                    ;;
                5)
                    echo "1. Install Go"
                    echo "2. Setup Environment"
                    echo "3. Install Tools"
                    read -rp "Select option: " go_option
                    case $go_option in
                        1)
                            sudo pacman -S go
                            ;;
                        2)
                            mkdir -p ~/go/{bin,src,pkg}
                            echo 'export GOPATH=$HOME/go' >> ~/.bashrc
                            echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
                            ;;
                        3)
                            go install golang.org/x/tools/gopls@latest
                            go install golang.org/x/lint/golint@latest
                            ;;
                    esac
                    ;;
                6)
                    echo "1. Install Rust"
                    echo "2. Install Development Tools"
                    echo "3. Configure Cargo"
                    read -rp "Select option: " rust_option
                    case $rust_option in
                        1)
                            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                            ;;
                        2)
                            rustup component add rustfmt clippy
                            ;;
                        3)
                            mkdir -p ~/.cargo
                            echo '[build]' >> ~/.cargo/config
                            echo 'jobs = 8' >> ~/.cargo/config
                            ;;
                    esac
                    ;;
            esac
            ;;
        4)
            echo "1. Install VS Code"
            echo "2. Install Neovim"
            echo "3. Install JetBrains Toolbox"
            echo "4. Install Sublime Text"
            echo "5. Install Emacs"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if confirm_action "Install VS Code?"; then
                        sudo pacman -S visual-studio-code-bin
                    fi
                    ;;
                2)
                    if confirm_action "Install Neovim?"; then
                        sudo pacman -S neovim python-pynvim
                        mkdir -p ~/.config/nvim
                        curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
                            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
                    fi
                    ;;
                3)
                    if confirm_action "Install JetBrains Toolbox?"; then
                        yay -S jetbrains-toolbox
                    fi
                    ;;
                4)
                    if confirm_action "Install Sublime Text?"; then
                        curl -O https://download.sublimetext.com/sublimehq-pub.gpg
                        sudo pacman-key --add sublimehq-pub.gpg
                        sudo pacman-key --lsign-key 8A8F901A
                        rm sublimehq-pub.gpg
                        echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a /etc/pacman.conf
                        sudo pacman -Syu sublime-text
                    fi
                    ;;
                5)
                    if confirm_action "Install Emacs?"; then
                        sudo pacman -S emacs
                        git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
                        ~/.emacs.d/bin/doom install
                    fi
                    ;;
            esac
            ;;
        5)
            echo "1. Configure Make"
            echo "2. Configure CMake"
            echo "3. Configure Ninja"
            echo "4. Configure Meson"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if ! check_command make; then
                        sudo pacman -S make
                    fi
                    echo '.PHONY: all clean install uninstall' > Makefile
                    echo 'all:' >> Makefile
                    echo 'clean:' >> Makefile
                    echo 'install:' >> Makefile
                    echo 'uninstall:' >> Makefile
                    ;;
                2)
                    if ! check_command cmake; then
                        sudo pacman -S cmake
                    fi
                    echo 'cmake_minimum_required(VERSION 3.10)' > CMakeLists.txt
                    echo 'project(MyProject)' >> CMakeLists.txt
                    echo 'add_executable(${PROJECT_NAME} main.cpp)' >> CMakeLists.txt
                    ;;
                3)
                    if ! check_command ninja; then
                        sudo pacman -S ninja
                    fi
                    echo 'rule cc' > build.ninja
                    echo '  command = gcc $in -o $out' >> build.ninja
                    ;;
                4)
                    if ! check_command meson; then
                        sudo pacman -S meson
                    fi
                    echo 'project(''myproject'', ''cpp'')' > meson.build
                    echo 'executable(''myapp'', ''main.cpp'')' >> meson.build
                    ;;
            esac
            ;;
        6)
            echo "1. Install Docker"
            echo "2. Install Podman"
            echo "3. Install Kubernetes Tools"
            echo "4. Configure Container Settings"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if confirm_action "Install Docker?"; then
                        sudo pacman -S docker docker-compose
                        sudo systemctl enable docker
                        sudo systemctl start docker
                        sudo usermod -aG docker "$USER"
                    fi
                    ;;
                2)
                    if confirm_action "Install Podman?"; then
                        sudo pacman -S podman podman-compose
                    fi
                    ;;
                3)
                    if confirm_action "Install Kubernetes tools?"; then
                        sudo pacman -S kubectl minikube helm
                    fi
                    ;;
                4)
                    if [ -f /etc/docker/daemon.json ]; then
                        sudo $EDITOR /etc/docker/daemon.json
                    else
                        echo '{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}' | sudo tee /etc/docker/daemon.json
                    fi
                    ;;
            esac
            ;;
        7)
            echo "1. Install PostgreSQL"
            echo "2. Install MySQL/MariaDB"
            echo "3. Install MongoDB"
            echo "4. Install Redis"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if confirm_action "Install PostgreSQL?"; then
                        sudo pacman -S postgresql
                        sudo -u postgres initdb -D /var/lib/postgres/data
                        sudo systemctl enable postgresql
                        sudo systemctl start postgresql
                    fi
                    ;;
                2)
                    if confirm_action "Install MariaDB?"; then
                        sudo pacman -S mariadb
                        sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
                        sudo systemctl enable mariadb
                        sudo systemctl start mariadb
                        sudo mysql_secure_installation
                    fi
                    ;;
                3)
                    if confirm_action "Install MongoDB?"; then
                        yay -S mongodb-bin mongodb-tools-bin
                        sudo systemctl enable mongodb
                        sudo systemctl start mongodb
                    fi
                    ;;
                4)
                    if confirm_action "Install Redis?"; then
                        sudo pacman -S redis
                        sudo systemctl enable redis
                        sudo systemctl start redis
                    fi
                    ;;
            esac
            ;;
        8)
            echo "1. Configure Git Flow"
            echo "2. Setup Git LFS"
            echo "3. Configure Git Hooks"
            echo "4. Setup Git Credentials"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if ! check_command git-flow; then
                        sudo pacman -S git-flow
                    fi
                    git flow init
                    ;;
                2)
                    if ! check_command git-lfs; then
                        sudo pacman -S git-lfs
                    fi
                    git lfs install
                    ;;
                3)
                    mkdir -p .git/hooks
                    echo '#!/bin/sh
if ! command -v shellcheck >/dev/null 2>&1; then
    exit 0
fi
shellcheck "$@"' > .git/hooks/pre-commit
                    chmod +x .git/hooks/pre-commit
                    ;;
                4)
                    if ! check_command pass; then
                        sudo pacman -S pass
                    fi
                    pass init "$(git config --get user.email)"
                    git config --global credential.helper store
                    ;;
            esac
            ;;
        9)
            echo "1. Install Shell Tools"
            echo "2. Install Network Tools"
            echo "3. Install Documentation Tools"
            echo "4. Install Analysis Tools"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if confirm_action "Install shell tools?"; then
                        sudo pacman -S shellcheck bash-completion fzf ripgrep fd bat
                    fi
                    ;;
                2)
                    if confirm_action "Install network tools?"; then
                        sudo pacman -S curl wget netcat nmap wireshark-qt
                    fi
                    ;;
                3)
                    if confirm_action "Install documentation tools?"; then
                        sudo pacman -S doxygen graphviz plantuml
                    fi
                    ;;
                4)
                    if confirm_action "Install analysis tools?"; then
                        sudo pacman -S strace ltrace valgrind perf
                    fi
                    ;;
            esac
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

manage_virtualization() {
    print_section "Virtualization Management"
    
    echo "1. Install Virtualization Tools"
    echo "2. Configure KVM/QEMU"
    echo "3. Configure VirtualBox"
    echo "4. Configure LXC/LXD"
    echo "5. Configure Vagrant"
    echo "6. Manage Virtual Machines"
    echo "7. Manage Containers"
    echo "8. Network Configuration"
    echo "9. Storage Management"
    echo "0. Back"
    
    read -rp "Select option: " choice
    case $choice in
        1)
            echo "1. Install KVM/QEMU"
            echo "2. Install VirtualBox"
            echo "3. Install LXC/LXD"
            echo "4. Install Vagrant"
            echo "0. Back"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if confirm_action "Install KVM/QEMU?"; then
                        sudo pacman -S qemu-full virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libguestfs
                        sudo systemctl enable libvirtd
                        sudo systemctl start libvirtd
                        sudo usermod -aG libvirt "$USER"
                        sudo virsh net-autostart default
                        sudo virsh net-start default
                    fi
                    ;;
                2)
                    if confirm_action "Install VirtualBox?"; then
                        sudo pacman -S virtualbox virtualbox-host-dkms virtualbox-guest-iso
                        sudo modprobe vboxdrv
                        sudo usermod -aG vboxusers "$USER"
                    fi
                    ;;
                3)
                    if confirm_action "Install LXC/LXD?"; then
                        sudo pacman -S lxc lxd
                        sudo systemctl enable lxd
                        sudo systemctl start lxd
                        sudo usermod -aG lxd "$USER"
                        lxd init --auto
                    fi
                    ;;
                4)
                    if confirm_action "Install Vagrant?"; then
                        sudo pacman -S vagrant
                    fi
                    ;;
                0)
                    return
                    ;;
            esac
            ;;
        2)
            echo "1. Configure Network"
            echo "2. Configure Storage"
            echo "3. Configure Security"
            echo "4. Configure Performance"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    echo "1. Create Bridge Network"
                    echo "2. Configure NAT Network"
                    echo "3. Configure Host Network"
                    read -rp "Select option: " network_option
                    case $network_option in
                        1)
                            read -rp "Enter bridge name: " bridge
                            if [ -n "$bridge" ]; then
                                sudo virsh net-define /dev/stdin <<EOF
<network>
  <name>$bridge</name>
  <forward mode='bridge'/>
  <bridge name='$bridge'/>
</network>
EOF
                                sudo virsh net-autostart "$bridge"
                                sudo virsh net-start "$bridge"
                            fi
                            ;;
                        2)
                            read -rp "Enter network name: " network
                            if [ -n "$network" ]; then
                                sudo virsh net-define /dev/stdin <<EOF
<network>
  <name>$network</name>
  <forward mode='nat'/>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.2' end='192.168.100.254'/>
    </dhcp>
  </ip>
</network>
EOF
                                sudo virsh net-autostart "$network"
                                sudo virsh net-start "$network"
                            fi
                            ;;
                        3)
                            read -rp "Enter network interface: " interface
                            if [ -n "$interface" ]; then
                                sudo sysctl -w net.ipv4.ip_forward=1
                                sudo iptables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE
                            fi
                            ;;
                    esac
                    ;;
                2)
                    echo "1. Create Storage Pool"
                    echo "2. Configure Storage Pool"
                    echo "3. Create Volume"
                    read -rp "Select option: " storage_option
                    case $storage_option in
                        1)
                            read -rp "Enter pool name: " pool
                            read -rp "Enter pool path: " path
                            if [ -n "$pool" ] && [ -n "$path" ]; then
                                sudo virsh pool-define-as --name "$pool" --type dir --target "$path"
                                sudo virsh pool-build "$pool"
                                sudo virsh pool-start "$pool"
                                sudo virsh pool-autostart "$pool"
                            fi
                            ;;
                        2)
                            sudo virsh pool-list --all
                            read -rp "Enter pool name: " pool
                            if [ -n "$pool" ]; then
                                sudo virsh pool-edit "$pool"
                            fi
                            ;;
                        3)
                            sudo virsh pool-list --all
                            read -rp "Enter pool name: " pool
                            read -rp "Enter volume name: " name
                            read -rp "Enter size (e.g., 10G): " size
                            if [ -n "$pool" ] && [ -n "$name" ] && [ -n "$size" ]; then
                                sudo virsh vol-create-as "$pool" "$name" "$size"
                            fi
                            ;;
                    esac
                    ;;
                4)
                    echo "1. Configure SELinux"
                    echo "2. Configure AppArmor"
                    echo "3. Configure Seclabel"
                    read -rp "Select option: " security_option
                    case $security_option in
                        1)
                            if ! check_command semanage; then
                                sudo pacman -S selinux-utils
                            fi
                            sudo semanage fcontext -a -t virt_image_t "$HOME/.local/share/libvirt/images(/.*)?"
                            sudo restorecon -R "$HOME/.local/share/libvirt/images"
                            ;;
                        2)
                            if ! check_command aa-status; then
                                sudo pacman -S apparmor
                            fi
                            sudo systemctl enable apparmor
                            sudo systemctl start apparmor
                            ;;
                        3)
                            sudo $EDITOR /etc/libvirt/qemu.conf
                            sudo systemctl restart libvirtd
                            ;;
                    esac
                    ;;
                4)
                    echo "1. Configure CPU"
                    echo "2. Configure Memory"
                    echo "3. Configure I/O"
                    read -rp "Select option: " performance_option
                    case $performance_option in
                        1)
                            sudo $EDITOR /etc/modprobe.d/kvm.conf
                            echo "options kvm_intel nested=1" | sudo tee -a /etc/modprobe.d/kvm.conf
                            sudo modprobe -r kvm_intel
                            sudo modprobe kvm_intel
                            ;;
                        2)
                            echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-vm.conf
                            sudo sysctl -p /etc/sysctl.d/99-vm.conf
                            ;;
                        3)
                            echo "none /var/lib/libvirt/images xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
                            sudo mount -a
                            ;;
                    esac
                    ;;
            esac
            ;;
        3)
            echo "1. Configure Network"
            echo "2. Configure USB"
            echo "3. Configure Shared Folders"
            echo "4. Configure Extensions"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    VBoxManage list hostonlyifs
                    read -rp "Create new host-only network? (y/n): " create
                    if [ "$create" = "y" ]; then
                        VBoxManage hostonlyif create
                    fi
                    ;;
                2)
                    if ! groups | grep -q "vboxusers"; then
                        sudo usermod -aG vboxusers "$USER"
                        print_info "Please log out and back in for the changes to take effect"
                    fi
                    ;;
                3)
                    read -rp "Enter VM name: " vm
                    read -rp "Enter host path: " path
                    read -rp "Enter share name: " share
                    if [ -n "$vm" ] && [ -n "$path" ] && [ -n "$share" ]; then
                        VBoxManage sharedfolder add "$vm" --name "$share" --hostpath "$path" --automount
                    fi
                    ;;
                4)
                    if confirm_action "Install VirtualBox Extension Pack?"; then
                        version=$(VBoxManage -v | cut -d'r' -f1)
                        wget "https://download.virtualbox.org/virtualbox/$version/Oracle_VM_VirtualBox_Extension_Pack-$version.vbox-extpack"
                        sudo VBoxManage extpack install --replace "Oracle_VM_VirtualBox_Extension_Pack-$version.vbox-extpack"
                        rm "Oracle_VM_VirtualBox_Extension_Pack-$version.vbox-extpack"
                    fi
                    ;;
            esac
            ;;
        4)
            echo "1. Configure Storage Backend"
            echo "2. Configure Network"
            echo "3. Configure Profiles"
            echo "4. Configure Security"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    lxc storage list
                    read -rp "Create new storage pool? (y/n): " create
                    if [ "$create" = "y" ]; then
                        read -rp "Enter pool name: " pool
                        if [ -n "$pool" ]; then
                            lxc storage create "$pool" dir
                        fi
                    fi
                    ;;
                2)
                    lxc network list
                    read -rp "Create new network? (y/n): " create
                    if [ "$create" = "y" ]; then
                        read -rp "Enter network name: " network
                        if [ -n "$network" ]; then
                            lxc network create "$network"
                        fi
                    fi
                    ;;
                3)
                    lxc profile list
                    read -rp "Create new profile? (y/n): " create
                    if [ "$create" = "y" ]; then
                        read -rp "Enter profile name: " profile
                        if [ -n "$profile" ]; then
                            lxc profile create "$profile"
                            lxc profile edit "$profile"
                        fi
                    fi
                    ;;
                4)
                    sudo $EDITOR /etc/lxc/lxc.conf
                    sudo systemctl restart lxc
                    ;;
            esac
            ;;
        5)
            echo "1. Initialize Project"
            echo "2. Configure Provider"
            echo "3. Configure Network"
            echo "4. Configure Provisioner"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    read -rp "Enter project directory: " dir
                    if [ -n "$dir" ]; then
                        mkdir -p "$dir"
                        cd "$dir" || return
                        vagrant init
                    fi
                    ;;
                2)
                    if [ -f Vagrantfile ]; then
                        read -rp "Enter provider (virtualbox/libvirt): " provider
                        case $provider in
                            virtualbox)
                                sed -i 's/config.vm.box = "base"/config.vm.box = "generic\/arch"/' Vagrantfile
                                sed -i '/config.vm.provider "virtualbox" do |vb|/,+4 s/^  #//' Vagrantfile
                                ;;
                            libvirt)
                                sed -i 's/config.vm.box = "base"/config.vm.box = "generic\/arch"/' Vagrantfile
                                echo 'config.vm.provider :libvirt do |libvirt|
  libvirt.memory = 2048
  libvirt.cpus = 2
end' >> Vagrantfile
                                ;;
                        esac
                    fi
                    ;;
                3)
                    if [ -f Vagrantfile ]; then
                        read -rp "Configure port forwarding? (y/n): " forward
                        if [ "$forward" = "y" ]; then
                            read -rp "Enter guest port: " guest_port
                            read -rp "Enter host port: " host_port
                            if [ -n "$guest_port" ] && [ -n "$host_port" ]; then
                                echo "config.vm.network \"forwarded_port\", guest: $guest_port, host: $host_port" >> Vagrantfile
                            fi
                        fi
                    fi
                    ;;
                4)
                    if [ -f Vagrantfile ]; then
                        read -rp "Configure shell provisioner? (y/n): " shell
                        if [ "$shell" = "y" ]; then
                            echo 'config.vm.provision "shell", inline: <<-SHELL
  pacman -Syu --noconfirm
  pacman -S --noconfirm base-devel git
SHELL' >> Vagrantfile
                        fi
                    fi
                    ;;
            esac
            ;;
        6)
            echo "1. List VMs"
            echo "2. Create VM"
            echo "3. Start VM"
            echo "4. Stop VM"
            echo "5. Delete VM"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if check_command virsh; then
                        print_info "KVM/QEMU VMs:"
                        sudo virsh list --all
                    fi
                    if check_command VBoxManage; then
                        print_info "VirtualBox VMs:"
                        VBoxManage list vms
                    fi
                    ;;
                2)
                    echo "1. Create KVM/QEMU VM"
                    echo "2. Create VirtualBox VM"
                    read -rp "Select option: " vm_option
                    case $vm_option in
                        1)
                            read -rp "Enter VM name: " name
                            read -rp "Enter RAM size (MB): " ram
                            read -rp "Enter number of CPUs: " cpus
                            read -rp "Enter disk size (GB): " disk
                            if [ -n "$name" ] && [ -n "$ram" ] && [ -n "$cpus" ] && [ -n "$disk" ]; then
                                sudo virt-install \
                                    --name "$name" \
                                    --ram "$ram" \
                                    --vcpus "$cpus" \
                                    --disk size="$disk" \
                                    --os-variant archlinux \
                                    --network network=default \
                                    --graphics spice \
                                    --cdrom "$HOME/Downloads/archlinux.iso"
                            fi
                            ;;
                        2)
                            read -rp "Enter VM name: " name
                            read -rp "Enter RAM size (MB): " ram
                            read -rp "Enter number of CPUs: " cpus
                            read -rp "Enter disk size (MB): " disk
                            if [ -n "$name" ] && [ -n "$ram" ] && [ -n "$cpus" ] && [ -n "$disk" ]; then
                                VBoxManage createvm --name "$name" --ostype ArchLinux_64 --register
                                VBoxManage modifyvm "$name" --memory "$ram" --cpus "$cpus"
                                VBoxManage createhd --filename "$HOME/VirtualBox VMs/$name/$name.vdi" --size "$disk"
                                VBoxManage storagectl "$name" --name "SATA Controller" --add sata --controller IntelAhci
                                VBoxManage storageattach "$name" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/$name/$name.vdi"
                            fi
                            ;;
                    esac
                    ;;
                3)
                    echo "1. Start KVM/QEMU VM"
                    echo "2. Start VirtualBox VM"
                    read -rp "Select option: " vm_option
                    case $vm_option in
                        1)
                            sudo virsh list --all
                            read -rp "Enter VM name: " name
                            if [ -n "$name" ]; then
                                sudo virsh start "$name"
                                virt-viewer "$name"
                            fi
                            ;;
                        2)
                            VBoxManage list vms
                            read -rp "Enter VM name: " name
                            if [ -n "$name" ]; then
                                VBoxManage startvm "$name" --type gui
                            fi
                            ;;
                    esac
                    ;;
                4)
                    echo "1. Stop KVM/QEMU VM"
                    echo "2. Stop VirtualBox VM"
                    read -rp "Select option: " vm_option
                    case $vm_option in
                        1)
                            sudo virsh list
                            read -rp "Enter VM name: " name
                            if [ -n "$name" ]; then
                                sudo virsh shutdown "$name"
                            fi
                            ;;
                        2)
                            VBoxManage list runningvms
                            read -rp "Enter VM name: " name
                            if [ -n "$name" ]; then
                                VBoxManage controlvm "$name" acpipowerbutton
                            fi
                            ;;
                    esac
                    ;;
                5)
                    echo "1. Delete KVM/QEMU VM"
                    echo "2. Delete VirtualBox VM"
                    read -rp "Select option: " vm_option
                    case $vm_option in
                        1)
                            sudo virsh list --all
                            read -rp "Enter VM name: " name
                            if [ -n "$name" ]; then
                                sudo virsh destroy "$name"
                                sudo virsh undefine "$name" --remove-all-storage
                            fi
                            ;;
                        2)
                            VBoxManage list vms
                            read -rp "Enter VM name: " name
                            if [ -n "$name" ]; then
                                VBoxManage unregistervm "$name" --delete
                            fi
                            ;;
                    esac
                    ;;
            esac
            ;;
        7)
            echo "1. List Containers"
            echo "2. Create Container"
            echo "3. Start Container"
            echo "4. Stop Container"
            echo "5. Delete Container"
            read -rp "Select option: " suboption
            case $suboption in
                1)
                    if check_command lxc; then
                        print_info "LXC Containers:"
                        lxc list
                    fi
                    if check_command docker; then
                        print_info "Docker Containers:"
                        docker ps -a
                    fi
                    ;;
                2)
                    echo "1. Create LXC Container"
                    echo "2. Create Docker Container"
                    read -rp