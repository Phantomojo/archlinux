#!/bin/bash

# Arch Linux Automated Installer
# Based on ArchWiki installation guide and best practices
# https://wiki.archlinux.org/title/Installation_guide

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/tmp/arch-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Configuration variables (can be overridden by config file)
TARGET_DISK=""
HOSTNAME="archlinux"
USERNAME="archuser"
USER_PASSWORD=""
ROOT_PASSWORD=""
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
KEYMAP="us"
DESKTOP_ENVIRONMENT=""
INSTALL_AUR_HELPER="yay"
ADDITIONAL_PACKAGES=""
ENABLE_SERVICES="NetworkManager"
BOOTLOADER="systemd-boot"

# Partition sizes (in GB)
EFI_SIZE="512M"
SWAP_SIZE="4G"
ROOT_SIZE=""  # Empty means use remaining space

# Package lists
BASE_PACKAGES="base linux linux-firmware sudo vim nano networkmanager"
DESKTOP_PACKAGES=""
DEV_PACKAGES="git base-devel"

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_network() {
    log "Checking network connectivity..."
    if ! ping -c 1 archlinux.org &> /dev/null; then
        error "No internet connection. Please configure network first."
    fi
    log "Network connectivity confirmed"
}

load_config() {
    local config_file="${1:-/tmp/arch-install.conf}"
    if [[ -f "$config_file" ]]; then
        log "Loading configuration from $config_file"
        source "$config_file"
    else
        log "No config file found, using defaults"
    fi
}

detect_disks() {
    log "Detecting available disks..."
    local disks=($(lsblk -d -n -o NAME,TYPE,SIZE | grep disk | awk '{print $1}'))
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        error "No disks found"
    fi
    
    echo "Available disks:"
    for i in "${!disks[@]}"; do
        local size=$(lsblk -d -n -o SIZE "/dev/${disks[$i]}")
        echo "  $((i+1)). /dev/${disks[$i]} ($size)"
    done
    
    if [[ -z "$TARGET_DISK" ]]; then
        read -p "Select disk number (1-${#disks[@]}): " disk_choice
        if [[ "$disk_choice" -ge 1 && "$disk_choice" -le ${#disks[@]} ]]; then
            TARGET_DISK="/dev/${disks[$((disk_choice-1))]}"
        else
            error "Invalid disk selection"
        fi
    fi
    
    log "Selected disk: $TARGET_DISK"
}

get_user_input() {
    if [[ -z "$HOSTNAME" ]]; then
        read -p "Enter hostname [archlinux]: " input_hostname
        HOSTNAME="${input_hostname:-archlinux}"
    fi
    
    if [[ -z "$USERNAME" ]]; then
        read -p "Enter username [archuser]: " input_username
        USERNAME="${input_username:-archuser}"
    fi
    
    if [[ -z "$USER_PASSWORD" ]]; then
        read -s -p "Enter user password: " USER_PASSWORD
        echo
        read -s -p "Confirm user password: " confirm_password
        echo
        if [[ "$USER_PASSWORD" != "$confirm_password" ]]; then
            error "Passwords do not match"
        fi
    fi
    
    if [[ -z "$ROOT_PASSWORD" ]]; then
        read -s -p "Enter root password: " ROOT_PASSWORD
        echo
        read -s -p "Confirm root password: " confirm_password
        echo
        if [[ "$ROOT_PASSWORD" != "$confirm_password" ]]; then
            error "Passwords do not match"
        fi
    fi
}

wipe_disk() {
    log "Wiping disk $TARGET_DISK..."
    wipefs -a "$TARGET_DISK"
    partprobe "$TARGET_DISK"
}

partition_disk() {
    log "Creating partitions on $TARGET_DISK..."
    
    # Create partition table
    parted -s "$TARGET_DISK" mklabel gpt
    
    # Create EFI partition
    parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB "$EFI_SIZE"
    parted -s "$TARGET_DISK" set 1 esp on
    
    # Create swap partition
    local swap_start="$EFI_SIZE"
    local swap_end=$(echo "$EFI_SIZE" | sed 's/MiB//' | awk '{print ($1 + 4096) "MiB"}')
    parted -s "$TARGET_DISK" mkpart primary linux-swap "$swap_start" "$swap_end"
    
    # Create root partition
    local root_start="$swap_end"
    if [[ -n "$ROOT_SIZE" ]]; then
        local root_end=$(echo "$root_start" | sed 's/MiB//' | awk -v size="$ROOT_SIZE" '{print ($1 + size*1024) "MiB"}')
        parted -s "$TARGET_DISK" mkpart primary ext4 "$root_start" "$root_end"
    else
        parted -s "$TARGET_DISK" mkpart primary ext4 "$root_start" 100%
    fi
    
    partprobe "$TARGET_DISK"
    sleep 2
}

format_partitions() {
    log "Formatting partitions..."
    
    # Format EFI partition
    mkfs.fat -F32 "${TARGET_DISK}1"
    
    # Format swap
    mkswap "${TARGET_DISK}2"
    swapon "${TARGET_DISK}2"
    
    # Format root partition
    mkfs.ext4 -F "${TARGET_DISK}3"
}

mount_partitions() {
    log "Mounting partitions..."
    
    # Mount root partition
    mount "${TARGET_DISK}3" /mnt
    
    # Create and mount EFI directory
    mkdir -p /mnt/boot
    mount "${TARGET_DISK}1" /mnt/boot
}

install_base_system() {
    log "Installing base system..."
    
    # Update keyring
    pacman -Sy --noconfirm archlinux-keyring
    
    # Install base packages
    local packages="$BASE_PACKAGES"
    
    # Add desktop environment packages if specified
    if [[ -n "$DESKTOP_ENVIRONMENT" ]]; then
        case "$DESKTOP_ENVIRONMENT" in
            "gnome")
                packages="$packages gnome gnome-extra"
                ;;
            "kde")
                packages="$packages plasma kde-applications"
                ;;
            "xfce")
                packages="$packages xfce4 xfce4-goodies"
                ;;
            "i3")
                packages="$packages i3-wm i3status i3lock dmenu"
                ;;
        esac
    fi
    
    # Add development packages if requested
    if [[ "$ADDITIONAL_PACKAGES" == *"dev"* ]]; then
        packages="$packages $DEV_PACKAGES"
    fi
    
    # Add custom packages
    if [[ -n "$ADDITIONAL_PACKAGES" ]]; then
        packages="$packages $ADDITIONAL_PACKAGES"
    fi
    
    pacstrap /mnt $packages
}

generate_fstab() {
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

configure_system() {
    log "Configuring system..."
    
    # Set timezone
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    # Configure locale
    arch-chroot /mnt sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    
    # Set keymap
    echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
    
    # Set hostname
    echo "$HOSTNAME" > /mnt/etc/hostname
    
    # Configure hosts file
    cat > /mnt/etc/hosts << EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF
}

create_user() {
    log "Creating user $USERNAME..."
    
    # Set root password
    arch-chroot /mnt bash -c "echo 'root:$ROOT_PASSWORD' | chpasswd"
    
    # Create user
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"
    arch-chroot /mnt bash -c "echo '$USERNAME:$USER_PASSWORD' | chpasswd"
    
    # Configure sudo
    arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
}

install_bootloader() {
    log "Installing bootloader..."
    
    case "$BOOTLOADER" in
        "systemd-boot")
            arch-chroot /mnt bootctl --path=/boot install
            
            # Create bootloader configuration
            cat > /mnt/boot/loader/loader.conf << EOF
default arch
timeout 3
editor  no
EOF
            
            # Get root UUID
            local root_uuid=$(blkid -s UUID -o value "${TARGET_DISK}3")
            
            # Create boot entry
            cat > /mnt/boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$root_uuid rw
EOF
            ;;
        "grub")
            arch-chroot /mnt pacman -S --noconfirm grub efibootmgr
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
    esac
}

enable_services() {
    log "Enabling services..."
    
    for service in $ENABLE_SERVICES; do
        arch-chroot /mnt systemctl enable "$service"
    done
}

install_aur_helper() {
    if [[ -n "$INSTALL_AUR_HELPER" ]]; then
        log "Installing AUR helper: $INSTALL_AUR_HELPER"
        
        # Install base-devel if not already installed
        arch-chroot /mnt pacman -S --noconfirm base-devel git
        
        # Create a temporary user for AUR builds
        arch-chroot /mnt useradd -m -s /bin/bash auruser
        arch-chroot /mnt bash -c "echo 'auruser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
        
        # Install AUR helper
        case "$INSTALL_AUR_HELPER" in
            "yay")
                arch-chroot /mnt su - auruser -c "cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"
                ;;
            "paru")
                arch-chroot /mnt su - auruser -c "cd /tmp && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si --noconfirm"
                ;;
        esac
        
        # Clean up temporary user
        arch-chroot /mnt userdel -r auruser
        arch-chroot /mnt sed -i '/auruser/d' /etc/sudoers
    fi
}

cleanup() {
    log "Cleaning up..."
    
    # Unmount partitions
    umount -R /mnt
    
    # Turn off swap
    swapoff -a
}

show_completion() {
    log "Installation completed successfully!"
    echo
    echo -e "${GREEN}System Information:${NC}"
    echo "  Hostname: $HOSTNAME"
    echo "  Username: $USERNAME"
    echo "  Desktop: $DESKTOP_ENVIRONMENT"
    echo "  Bootloader: $BOOTLOADER"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Remove the installation media"
    echo "  2. Reboot the system"
    echo "  3. Log in with your credentials"
    echo
    echo "Installation log saved to: $LOG_FILE"
}

main() {
    log "Starting Arch Linux automated installation..."
    
    # Check prerequisites
    check_root
    check_network
    
    # Load configuration
    load_config "$1"
    
    # Get user input if not provided in config
    detect_disks
    get_user_input
    
    # Confirmation
    echo
    echo -e "${YELLOW}Installation Summary:${NC}"
    echo "  Target Disk: $TARGET_DISK"
    echo "  Hostname: $HOSTNAME"
    echo "  Username: $USERNAME"
    echo "  Desktop: $DESKTOP_ENVIRONMENT"
    echo "  Bootloader: $BOOTLOADER"
    echo
    read -p "Continue with installation? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log "Installation cancelled"
        exit 0
    fi
    
    # Installation steps
    wipe_disk
    partition_disk
    format_partitions
    mount_partitions
    install_base_system
    generate_fstab
    configure_system
    create_user
    install_bootloader
    enable_services
    install_aur_helper
    cleanup
    show_completion
    
    log "Installation completed. Rebooting in 10 seconds..."
    sleep 10
    reboot
}

# Run main function with any config file argument
main "$@"
