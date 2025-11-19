#!/bin/bash

# Define the mount points for the root partition and optional boot partition
ROOT_PARTITION="/dev/sdX1"   # Change this to your root partition (e.g., /dev/sda1)
BOOT_PARTITION="/dev/sdX2"   # Change this to your boot partition, if you have one (e.g., /dev/sda2)

# Create mount point directories
MOUNT_DIR="/mnt/linux"
BOOT_DIR="/mnt/linux/boot"

echo "Mounting root filesystem..."
sudo mount $ROOT_PARTITION $MOUNT_DIR

# If you have a separate boot partition, mount it
if [ -n "$BOOT_PARTITION" ]; then
    echo "Mounting boot partition..."
    sudo mount $BOOT_PARTITION $BOOT_DIR
fi

# Mount necessary virtual filesystems for chroot
echo "Mounting virtual filesystems for chroot..."
sudo mount --bind /dev $MOUNT_DIR/dev
sudo mount --bind /proc $MOUNT_DIR/proc
sudo mount --bind /sys $MOUNT_DIR/sys
sudo mount --bind /run $MOUNT_DIR/run

# Chroot into the mounted system
echo "Entering chroot environment..."
sudo chroot $MOUNT_DIR /bin/bash <<EOF
    # Now you are inside the chroot, and can run the rebuild script
    echo "Running rebuild-inframs.sh..."
    /home/duckyonquack999/GitHub-Repositories/dotfiles/Linux/Scripts/rebuild-inframs.sh
EOF

# Exit chroot and unmount the filesystems
echo "Exiting chroot environment..."
sudo umount $MOUNT_DIR/run
sudo umount $MOUNT_DIR/sys
sudo umount $MOUNT_DIR/proc
sudo umount $MOUNT_DIR/dev

echo "Unmounting root and boot filesystems..."
sudo umount $MOUNT_DIR
if [ -n "$BOOT_PARTITION" ]; then
    sudo umount $BOOT_DIR
fi

echo "Repair process completed!"
