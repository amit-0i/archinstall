#!/bin/bash

delay = 0.5



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

# Setting bigger font size
setfont ter-122b


# Checking available disks.
echo "=== Disks and Partitions ==="
lsblk


# Choose a disk to install Arch linux on.
read -p "Select disk to install Arch linux on (ex:- /dev/sda or /dev/nvme0n1):- " disk_selected
DISK="/dev/$disk_selected"
echo "You selected: $DISK"
echo "Note everything on $DISK will be wiped out!"

if [ -b "$DISK" ]; then
    echo "Disk exists and is valid."
else
    echo "Error: Disk $selected_disk does not exist!"
    exit 1
fi
sleep $delay


# Partitioning disk.
echo "Partitioning the disk $DISK..."
parted "$DISK" mklabel gpt
parted "$DISK" mkpart primary fat32 1MiB 513MiB
parted "$DISK" set 1 esp on
parted "$DISK" name 1 BOOT
parted "$DISK" mkpart primary ext4 513MiB 100%
parted "$DISK" name 2 ROOT

echo "Partitioning completed"
sleep $delay


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
echo "Disks formated"
sleep $delay


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

echo "Scanning for Windows EFI partitions..."
WINDOWS_EFI=""
for part in /dev/nvme0n1p1 /dev/sda1 /dev/sda2 /dev/nvme0n1p2 /dev/sdb1; do
    if [ -b "$part" ] && blkid -t TYPE="vfat" "$part" >/dev/null; then
        WINDOWS_EFI="$part"
        echo "Found Windows EFI partition at $WINDOWS_EFI"
        mkdir -p /mnt/boot/windows-efi
        mount "$WINDOWS_EFI" /mnt/boot/windows-efi
        break
    fi
done

echo "Partitions mounted"
sleep $delay


# Ranking mirrors
reflector --country India --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
echo "Mirrors selected"
sleep $delay


# Installing packages
pacstrap -K /mnt base base-devel linux-zen linux-firmware intel-ucode dosfstools e2fsprogs ntfs-3g xfsprogs btrfs-progs efibootmgr grub os-prober networkmanager sudo vim nano man-pages man-db texinfo tealdeer git


# Generate fstab file.
genfstab -U /mnt >> /mnt/etc/fstab
echo "fstab file generated"
sleep $delay


# chrooting into arch.
arch-chroot /mnt /bin/bash << 'EOF'

# Time and locale 
timedatectl set-timezone Asia/Kolkata
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

sed -i '/en_US.UTF-8/s/^#//g' "/etc/locale.gen"
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Time and Locale configured"
sleep $delay


# Network Manager
echo "void" > /etc/hostname
systemctl enable NetworkManager
echo "Network manager configured"
sleep $delay


# Users and root
echo "Please enter password for root user."
passwd
sed -i '/^# %wheel  ALL=(ALL)       ALL/s/^# //' /etc/sudoers
useradd -m -G wheel -s /bin/bash okkotsu
passwd okkotsu
echo "User added"
sleep $delay

# GRUB installation
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --removable --recheck
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --recheck

sed -i '/#GRUB_DISABLE_OS_PROBER/s/^#//' "/etc/default/grub"

grub-mkconfig -o /boot/grub/grub.cfg

echo "Grub configured"
echo "Exiting chroot..."
sleep $delay

EOF

umount -R /mnt

echo "[✔] Installation complete. You can now reboot your system."