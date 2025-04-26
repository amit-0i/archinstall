#!/bin/bash

# check if the script is running as root.
if [ $EUID -ne 0 ]; then
    echo "Script did not ran as root."
    echo "Exiting..."
    exit 1
fi


# check if the system is ran in UEFI mode.
if [ ! -d "/sys/firmware/efi" ]; then 
    echo "System is not booted in UEFI mode, please reboot the system in UEFI mode."
    echo "Exiting..."
    exit 1
fi


# Set a bigger font size for user to read.
setfont ter-122b

# Checking for available disks and partitions

lsblk