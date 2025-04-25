#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Check if the system is booted in UEFI mode.
if [ ! -d "/sys/firmware/efi" ]; then
    echo "System is not booted in UEFI mode."
    exit 1
fi

# Checking available disks.
echo "=== Disks and Partitions ==="
lsblk -o NAME, SIZE, TYPE, MOUNTPOINT

# Choose a disk to install Arch linux on.
read -p "Select disk to install Arch linux on (ex:- /dev/sda or /dev/nvme0n1):- " disk_selected
DISK="/dev/$disk_selected"

echo "You selected: $DISK"

if [ -b "$DISK" ]; then
    echo "Disk exists and is valid."
else
    echo "Error: Disk $selected_disk does not exist!"
    exit 1
fi

# Partitioning disk.
echo "Partitioning the disk $DISK..."
parted "$DISK" mklabel gpt
parted "$DISK" mkpart primary fat32 1MiB 513MiB
parted "$DISK" set 1 esp on
parted "$DISK" name 1 BOOT
parted "$DISK" mkpart primary ext4 513MiB 100%
parted "$DISK" name 2 ROOT