#!/bin/bash

# Ensure dialog is installed
if ! command -v dialog &>/dev/null; then
    echo "dialog not found, installing..."
    sudo pacman -S --noconfirm dialog
fi

STEAM_PATH="$HOME/.local/share/Steam"
COMPATDATA="$STEAM_PATH/steamapps/compatdata"

# Function to inject/rebuild prefix
inject_prefix() {
    read -p "Enter APPID: " APPID
    PREFIX_PATH="$COMPATDATA/$APPID"
    if [[ -d "$PREFIX_PATH" ]]; then
        echo "Removing existing prefix..."
        rm -rf "$PREFIX_PATH"
        echo "Prefix removed. Relaunch Steam to rebuild."
    else
        echo "Prefix not found for APPID $APPID"
    fi
}

# Install Visual C++ runtimes via winetricks
install_vcruntime() {
    read -p "Enter APPID: " APPID
    PREFIX_PATH="$COMPATDATA/$APPID/pfx"
    if [[ ! -d "$PREFIX_PATH" ]]; then
        echo "Prefix not found, creating..."
        mkdir -p "$PREFIX_PATH"
    fi
    echo "Installing VC++ runtimes..."
    WINEPREFIX="$PREFIX_PATH" winetricks -q vcrun2015 vcrun2017 vcrun2019
}

# Auto-detect Proton versions
detect_proton() {
    echo "Detected Proton versions:"
    ls -1 "$STEAM_PATH/compatibilitytools.d" 2>/dev/null || echo "No custom Proton versions found"
}

# Repair Steam Linux Runtime
repair_runtime() {
    echo "Rebuilding Steam Linux Runtime..."
    STEAM_RUNTIME="$STEAM_PATH/ubuntu12_32/steam-runtime"
    if [[ -d "$STEAM_RUNTIME" ]]; then
        rm -rf "$STEAM_RUNTIME"
        echo "Removed old runtime. Relaunch Steam to auto-rebuild."
    else
        echo "Steam Runtime not found."
    fi
}

# Force global Proton version
force_global_proton() {
    detect_proton
    read -p "Enter Proton version to set globally (e.g., Proton-8.0): " PROTON_VER
    if [[ -d "$STEAM_PATH/compatibilitytools.d/$PROTON_VER" ]]; then
        mkdir -p "$STEAM_PATH/config"
        echo -e "[Steam]\nglobal_proton_version=$PROTON_VER" > "$STEAM_PATH/config/global_proton.cfg"
        echo "Global Proton version set to $PROTON_VER. Relaunch Steam."
    else
        echo "Proton version not found."
    fi
}

# Main dialog menu
while true; do
    OPTION=$(dialog --clear --title "Steam Proton Helper" \
        --menu "Select an action:" 15 50 6 \
        1 "Inject / Rebuild Prefix" \
        2 "Install Visual C++ Runtimes" \
        3 "Detect Proton Versions" \
        4 "Repair Steam Runtime" \
        5 "Force Global Proton Version" \
        6 "Exit" 3>&1 1>&2 2>&3)

    clear
    case $OPTION in
        1) inject_prefix ;;
        2) install_vcruntime ;;
        3) detect_proton ;;
        4) repair_runtime ;;
        5) force_global_proton ;;
        6) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    read -p "Press Enter to continue..."
done
