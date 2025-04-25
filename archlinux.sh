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


# Formatting partitions
echo "Formatting partitions"

if [[ "$DISK" =~ ^/dev/nvme ]]; then
    # If disk is NVMe
    mkfs.fat -F 32 "${DISK}p1"
    mkfs.ext4 "${DISK}p2"
else
    # If disk is SATA (e.g., /dev/sda)
    mkfs.fat -F 32 "${DISK}1"
    mkfs.ext4 "${DISK}2"
fi

# Mounting partitions
if [[ "$DISK" =~ ^/dev/nvme ]]; then
    # If disk is NVMe
    mount "${DISK}p2" /mnt
    mkdir -p /mnt/boot/efi
    mount "${DISK}p1" /mnt/boot/efi
else
    # If disk is SATA (e.g., /dev/sda)
    mount "${DISK}2" /mnt
    mkdir -p /mnt/boot/efi
    mount "${DISK}1" /mnt/boot/efi
fi

# Ranking mirrors
reflector --country India --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Installing packages
pacstrap -K /mnt base base-devel linux-zen linux-firmware intel-ucode dosfstools e2fsprogs ntfs-3g xfsprogs btrfs-progs efibootmgr grub os-prober networkmanager sudo vim nano man-pages man-db texinfo tealdeer git

# Generate fstab file.
genfstab -U /mnt >> /mnt/etc/fstab