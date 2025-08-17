#!/bin/bash

set -e


read -p "Enter username for the user account: " username
echo
read -p "Enter hostname for the system: " hostname
echo
read -s -p "Enter root password: " rootpass
echo
read -s -p "Enter password for user $username: " userpass
echo


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
setfont ter-120b


# Checking available disks.
echo "===================================="
echo "|       Disks and Partitions       |"
echo "===================================="
lsblk


# Choose a disk to install Arch linux on.
read -p "Select disk to install Arch linux on (e.g.:- sda or nvme0n1):- " disk_selected
DISK="/dev/$disk_selected"
echo "You have selected: $DISK"

if [ -b "$DISK" ]; then
    echo "Disk exists and is valid."
else
    echo "Error: Disk $disk_selected does not exist!"
    exit 1
fi

echo "Note everything on $DISK will be wiped out!"
sleep 2


# Partitioning disk.
echo "Partitioning the disk $DISK..."

read -p "1. Only root '\'
2. Root and Home (50GiB for root, rest for home )'\' 
3. Root, Swap and Home. (50GiB for root, 8GiB for swap, rest for home )'\'
Choose partition layout 1, 2 or 3 :- " part_ans
echo

if [ $part_ans -eq 1 ]; then
    parted "$DISK" mklabel gpt
    parted "$DISK" mkpart primary fat32 1MiB 1025MiB
    parted "$DISK" set 1 esp on
    parted "$DISK" name 1 BOOT
    parted "$DISK" mkpart primary btrfs 1025MiB 100%
    parted "$DISK" name 2 ROOT
elif [ $part_ans -eq 2 ]; then
    parted "$DISK" mklabel gpt
    parted "$DISK" mkpart primary fat32 1MiB 1025MiB
    parted "$DISK" set 1 esp on
    parted "$DISK" name 1 BOOT
    parted "$DISK" mkpart primary btrfs 1025MiB 51GiB
    parted "$DISK" name 2 ROOT
    parted "$DISK" mkpart primary xfs 51GiB 100%
    parted "$DISK" name 3 HOME
elif [ $part_ans -eq 3 ]; then
    parted "$DISK" mklabel gpt
    parted "$DISK" mkpart primary fat32 1MiB 1025MiB
    parted "$DISK" set 1 esp on
    parted "$DISK" name 1 BOOT
    parted "$DISK" mkpart primary linux-swap 1025MiB 9GiB
    parted "$DISK" name 2 SWAP
    parted "$DISK" mkpart primary btrfs 9GiB 59GiB
    parted "$DISK" name 3 ROOT
    parted "$DISK" mkpart primary xfs 59GiB 100%
    parted "$DISK" name 4 HOME
else
    echo "invalid option chosen"
    exit 1
fi

echo "Partitioning completed"
sleep 2


# Formatting partitions
echo "Formatting partitions"

# If disk is NVMe
if [[ "$DISK" =~ ^/dev/nvme ]]; then
        if [ $part_ans -eq 1 ]; then
            mkfs.fat -F 32 -n BOOT "${DISK}p1"
            mkfs.btrfs -f -L ROOT "${DISK}p2"
        elif [ $part_ans -eq 2 ]; then
            mkfs.fat -F 32 -n BOOT "${DISK}p1"
            mkfs.btrfs -f -L ROOT "${DISK}p2"
            mkfs.xfs -L HOME "${DISK}p3"
        elif [ $part_ans -eq 3 ]; then
            mkfs.fat -F 32 -n BOOT "${DISK}p1"
            mkswap "${DISK}p2"
            mkfs.btrfs -f -L ROOT "${DISK}p3"
            mkfs.xfs -L HOME "${DISK}p4"
        else
            echo "Error: could not format the partitions"
            exit 1
fi

else
    # If disk is SATA (e.g., /dev/sda)
    if [ $part_ans -eq 1 ]; then
            mkfs.fat -F 32 -n BOOT "${DISK}1"
            mkfs.btrfs -f -L ROOT "${DISK}2"
        elif [ $part_ans -eq 2 ]; then
            mkfs.fat -F 32 -n BOOT "${DISK}1"
            mkfs.btrfs -f -L ROOT "${DISK}2"
            mkfs.xfs -L HOME "${DISK}3"
        elif [ $part_ans -eq 3 ]; then
            mkfs.fat -F 32 -n BOOT "${DISK}1"
            mkswap "${DISK}2"
            mkfs.btrfs -f -L ROOT "${DISK}3"
            mkfs.xfs -L HOME "${DISK}4"
        else
            echo "Error: could not format the partitions"
            exit 1
    fi
fi
echo "Disks formated"
sleep 2


# Mounting partitions
if [[ "$DISK" =~ ^/dev/nvme ]]; then
    # If disk is NVMe
    mount "${DISK}p2" /mnt
    mkdir -p /mnt/boot/efi
    mount "${DISK}p1" /mnt/boot/efi
    mkdir -p /mnt/home
    mount "${DISK}p3" /mnt/home
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
        read -p "Do you want to mount it? y/n : " mnt_ans
        if [[ $mnt_ans =~ ^[yY]$ ]]; then
            mkdir -p /mnt/boot/windows-efi
            mount "$WINDOWS_EFI" /mnt/boot/windows-efi
        fi
        break
    fi
done

echo "Partitions mounted"
sleep 2


# Ranking mirrors
reflector --country India --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
echo "Mirrors selected"
sleep 2


# Installing packages
pacstrap -K /mnt base base-devel linux-zen linux-firmware intel-ucode dosfstools e2fsprogs ntfs-3g xfsprogs btrfs-progs efibootmgr grub os-prober networkmanager sudo vim nano man-pages man-db texinfo tealdeer git


# Generate fstab file.
genfstab -U /mnt >> /mnt/etc/fstab
echo "fstab file generated"
sleep 2


# chrooting into arch.
arch-chroot /mnt /bin/bash << EOF

# Time and locale 
timedatectl set-timezone Asia/Kolkata
timedatectl set-ntp 1
timedatectl set-local-rtc 1
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

sed -i '/en_US.UTF-8/s/^#//g' "/etc/locale.gen"
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Time and Locale configured"
sleep 2


# Network Manager
echo "$hostname" > /etc/hostname
systemctl enable NetworkManager
echo "Network manager configured"
sleep 2


# Users and root

echo "Setting root password..."
echo "root:$rootpass" | chpasswd

echo "Creating user '$username'..."
useradd -m -G wheel -s /bin/bash $username
echo "$username:$userpass" | chpasswd

# Uncomment %wheel in sudoers
echo "Configuring sudo for wheel group..."
EDITOR='sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/"' visudo


# GRUB installation
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --removable --recheck
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --recheck

sed -i '/#GRUB_DISABLE_OS_PROBER/s/^#//' "/etc/default/grub"

grub-mkconfig -o /boot/grub/grub.cfg

echo "Grub configured"
echo "Exiting chroot..."
sleep 2


# Updating tealdeer
tldr --update
EOF

umount -R /mnt

echo "Installation complete. You can now reboot your system."
