#!/bin/bash

# Script: setup_windows11_vm_tpm.sh
# Description: Automates setup of TPM 2.0 for new or existing Windows 11 VM in GNOME Boxes.
# Requirements: Run on Linux with libvirt/QEMU; sudo access needed; internet for optional download.
# Usage: ./setup_windows11_vm_tpm.sh
# Note: Supports creating new VM or adding TPM to existing one; handles GNOME Boxes compatibility.
# Update: Added mode selection for new/existing VM; 'gi' module troubleshooting.
# Update: Improved distro detection using /etc/os-release for accurate package manager selection.
# Update: Added support for Arch Linux with pacman and specific paths/packages.

# Default values - customize as needed
VM_NAME="Windows11"
RAM_MB=8192 # 8 GB
VCPUS=4
DISK_SIZE_GB=128
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
WIN_ISO="/run/media/duckyonquack999/NVME | OS/26200.6899_amd64_en-us_core_37896fbb_convert/Win11_25H2_English_x64.iso"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
VIRTIO_TMP="/tmp/virtio-win.iso"

# Detect distro using /etc/os-release
if [ -f /etc/os-release ]; then
    source /etc/os-release
    case "$ID" in
    fedora)
        PKG_MANAGER="dnf"
        UPDATE_CMD="sudo $PKG_MANAGER update -y"
        INSTALL_CMD="sudo $PKG_MANAGER install -y"
        REINSTALL_CMD="sudo $PKG_MANAGER reinstall -y"
        GI_PKG="python3-gobject"
        OVMF_PATH="/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd"
        OVMF_VARS="/usr/share/edk2/ovmf/OVMF_VARS.secboot.fd"
        PACKAGES="virt-install virt-manager swtpm swtpm-tools edk2-ovmf qemu-kvm libvirt curl python3-gobject"
        ;;
    ubuntu | debian | pop | linuxmint)
        PKG_MANAGER="apt"
        UPDATE_CMD="sudo $PKG_MANAGER update -y"
        INSTALL_CMD="sudo $PKG_MANAGER install -y"
        REINSTALL_CMD="sudo $PKG_MANAGER install --reinstall -y"
        GI_PKG="python3-gi"
        OVMF_PATH="/usr/share/OVMF/OVMF_CODE.secboot.fd"
        OVMF_VARS="/usr/share/OVMF/OVMF_VARS.secboot.fd"
        PACKAGES="virtinst virt-manager swtpm swtpm-tools ovmf qemu-kvm libvirt-clients libvirt-daemon-system curl python3-gi"
        ;;
    arch)
        PKG_MANAGER="pacman"
        UPDATE_CMD="sudo $PKG_MANAGER -Syu --noconfirm"
        INSTALL_CMD="sudo $PKG_MANAGER -S --needed --noconfirm"
        REINSTALL_CMD="sudo $PKG_MANAGER -S --needed --noconfirm"
        GI_PKG="python-gobject"
        OVMF_PATH="/usr/share/edk2/x64/OVMF_CODE.secboot.fd"
        OVMF_VARS="/usr/share/edk2/x64/OVMF_VARS.secboot.fd"
        PACKAGES="virt-install virt-manager swtpm edk2-ovmf qemu-desktop libvirt curl python-gobject dnsmasq ebtables iptables-nft"
        ;;
    *)
        echo "Unsupported distribution: $ID. Script supports Fedora, Ubuntu/Debian derivatives, and Arch."
        exit 1
        ;;
    esac
else
    echo "/etc/os-release not found. Unsupported distribution."
    exit 1
fi

# Install required packages
echo "Installing required packages..."
$UPDATE_CMD
$INSTALL_CMD $PACKAGES

# Troubleshoot 'gi' module if virt-install fails
if ! virt-install --version >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "Detected Homebrew. Unlinking Python to use system version..."
        brew unlink python3
    fi
    echo "Reinstalling Python GI package..."
    $REINSTALL_CMD $GI_PKG
    if ! virt-install --version >/dev/null 2>&1; then
        echo "virt-install still failing. Check Python path or manual install."
        exit 1
    fi
fi

# Configure swtpm if needed
if ! [ -f ~/.config/swtpm_setup.conf ]; then
    swtpm_setup --create-config-files skip-if-exist
fi

# For Arch, remind to enable services
if [ "$ID" = "arch" ]; then
    echo "On Arch, enable and start libvirtd: sudo systemctl enable --now libvirtd"
fi

# Mode selection: new or existing VM
read -p "Configure TPM for (n)ew VM or (e)xisting VM? (n/e): " MODE
if [ "$MODE" = "e" ] || [ "$MODE" = "E" ]; then
    read -p "Enter existing VM name: " VM_NAME
    if ! virsh list --all | grep -q "$VM_NAME"; then
        echo "VM '$VM_NAME' not found. List with 'virsh list --all'. Exiting."
        exit 1
    fi
    # Shut down if running
    virsh shutdown "$VM_NAME" 2>/dev/null
    # Dump XML
    XML_FILE="/tmp/${VM_NAME}.xml"
    virsh dumpxml "$VM_NAME" >"$XML_FILE"
    # Add TPM if not present
    if ! grep -q "<tpm" "$XML_FILE"; then
        sed -i '/<\/devices>/i \  <tpm model="tpm-crb">\n    <backend type="emulator" version="2.0"\/>\n  <\/tpm>' "$XML_FILE"
        echo "Added TPM 2.0 to XML."
    else
        echo "TPM already present in XML."
    fi
    # Ensure UEFI secure boot (check features and os)
    if ! grep -q "<smm state='on'/>" "$XML_FILE"; then
        sed -i '/<\/features>/i \  <smm state="on"\/>' "$XML_FILE"
    fi
    if ! grep -q "loader readonly='yes' secure='yes' type='pflash'" "$XML_FILE"; then
        sed -i "s/<loader readonly='yes' type='pflash'>.*<\/loader>/<loader readonly='yes' secure='yes' type='pflash'>$OVMF_PATH<\/loader>/" "$XML_FILE"
        sed -i "s/<nvram>.*<\/nvram>/<nvram template='$OVMF_VARS'\/>/" "$XML_FILE"
        echo "Updated to secure boot UEFI."
    fi
    # Redefine VM
    virsh define "$XML_FILE"
    if [ $? -eq 0 ]; then
        echo "VM '$VM_NAME' updated with TPM 2.0. Start in GNOME Boxes."
    else
        echo "Failed to define VM. Check XML: $XML_FILE"
        exit 1
    fi
else
    # New VM creation (original logic)
    # Check Windows ISO
    if [ ! -f "$WIN_ISO" ]; then
        echo "Windows ISO not found at '$WIN_ISO'. Please verify the path and try again."
        exit 1
    fi

    # Prompt for virtio-win ISO
    read -p "Enter path to virtio-win ISO (leave empty to download automatically): " VIRTIO_ISO
    if [ -z "$VIRTIO_ISO" ] || [ ! -f "$VIRTIO_ISO" ]; then
        read -p "virtio-win ISO not found or not provided. Download from stable source? (y/n): " CONFIRM
        if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
            echo "Downloading virtio-win.iso from $VIRTIO_URL..."
            curl -L -o "$VIRTIO_TMP" "$VIRTIO_URL"
            if [ $? -eq 0 ] && [ -f "$VIRTIO_TMP" ]; then
                VIRTIO_ISO="$VIRTIO_TMP"
                echo "Download complete. Using $VIRTIO_ISO"
            else
                echo "Download failed. Please download manually and provide path."
                exit 1
            fi
        else
            echo "Exiting. Please provide a valid path to virtio-win ISO."
            exit 1
        fi
    fi

    # Create VM using virt-install
    echo "Creating VM: $VM_NAME"
    sudo virt-install \
        --name "$VM_NAME" \
        --ram $RAM_MB \
        --vcpus $VCPUS \
        --cpu host-passthrough \
        --os-variant win11 \
        --disk path="$DISK_PATH",size=$DISK_SIZE_GB,bus=virtio,format=qcow2 \
        --cdrom "$WIN_ISO" \
        --disk path="$VIRTIO_ISO",device=cdrom \
        --network bridge=virbr0,model=virtio \
        --graphics spice \
        --video virtio \
        --features kvm_hidden=on,smm=on \
        --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
        --boot loader="$OVMF_PATH",loader_ro=yes,loader_type=pflash,nvram_template="$OVMF_VARS",loader_secure=yes \
        --noautoconsole

    if [ $? -eq 0 ]; then
        echo "VM created successfully. Open GNOME Boxes to start the VM and proceed with Windows 11 installation."
        echo "During install: Load virtio drivers from the second CDROM when prompted for storage/network."
        echo "Post-install: Install guest tools from virtio-win ISO."
        echo "Note: Using stable virtio-win; if issues, try archive versions."
    else
        echo "VM creation failed. Check logs with 'virsh dumpxml $VM_NAME'."
        echo "If 'gi' error, verify system Python: 'which python3' should be /usr/bin/python3."
    fi
fi
