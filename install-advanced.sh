#!/bin/bash

# Advanced Arch Linux Automated Installer with LUKS/LVM Support
# Optimized for Michael's system: i7-12700H + RTX 3050 Ti + 1TB NVMe

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/tmp/arch-advanced-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Configuration variables
TARGET_DISK=""
HOSTNAME="michael-arch"
USERNAME="michael"
USER_PASSWORD=""
ROOT_PASSWORD=""
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"
DESKTOP_ENVIRONMENT="i3"
INSTALL_AUR_HELPER="paru"
BOOTLOADER="systemd-boot"

# LUKS/LVM Configuration
LUKS_ENABLE="false"
LUKS_PASSWORD=""
LVM_ENABLE="false"
LVM_VG_NAME="arch-vg"
LVM_ROOT_SIZE="100G"
LVM_SWAP_SIZE="8G"
WAREHOUSE_ENABLE="false"
WAREHOUSE_SIZE=""

# Partition sizes
EFI_SIZE="512M"

# Package lists
BASE_PACKAGES="base linux linux-firmware sudo vim nano networkmanager"
ADDITIONAL_PACKAGES=""
ENABLE_SERVICES="NetworkManager"

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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
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
        error "Configuration file not found: $config_file"
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

wipe_disk() {
    log "Wiping disk $TARGET_DISK..."
    wipefs -a "$TARGET_DISK"
    partprobe "$TARGET_DISK"
}

create_partitions_advanced() {
    log "Creating advanced partition layout..."
    
    # Create partition table
    parted -s "$TARGET_DISK" mklabel gpt
    
    # Create EFI partition
    parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB "$EFI_SIZE"
    parted -s "$TARGET_DISK" set 1 esp on
    
    if [[ "$LUKS_ENABLE" == "true" ]]; then
        # Create LUKS partition for encrypted LVM
        local luks_start="$EFI_SIZE"
        local luks_end=""
        
        if [[ "$WAREHOUSE_ENABLE" == "true" && -n "$WAREHOUSE_SIZE" ]]; then
            # Calculate warehouse partition size
            local total_size=$(lsblk -d -n -o SIZE "$TARGET_DISK" | sed 's/G.*//')
            local luks_size=$(echo "$total_size - $WAREHOUSE_SIZE" | bc)
            luks_end="${luks_size}G"
        else
            luks_end="100%"
        fi
        
        parted -s "$TARGET_DISK" mkpart primary ext4 "$luks_start" "$luks_end"
        
        # Create warehouse partition if enabled
        if [[ "$WAREHOUSE_ENABLE" == "true" && -n "$WAREHOUSE_SIZE" ]]; then
            local warehouse_start="$luks_end"
            parted -s "$TARGET_DISK" mkpart primary ext4 "$warehouse_start" 100%
        fi
    else
        # Standard partitioning
        local swap_start="$EFI_SIZE"
        local swap_end=$(echo "$EFI_SIZE" | sed 's/MiB//' | awk '{print ($1 + 8192) "MiB"}')
        parted -s "$TARGET_DISK" mkpart primary linux-swap "$swap_start" "$swap_end"
        
        local root_start="$swap_end"
        if [[ -n "$WAREHOUSE_SIZE" ]]; then
            local total_size=$(lsblk -d -n -o SIZE "$TARGET_DISK" | sed 's/G.*//')
            local root_size=$(echo "$total_size - $WAREHOUSE_SIZE" | bc)
            local root_end="${root_size}G"
            parted -s "$TARGET_DISK" mkpart primary ext4 "$root_start" "$root_end"
            parted -s "$TARGET_DISK" mkpart primary ext4 "$root_end" 100%
        else
            parted -s "$TARGET_DISK" mkpart primary ext4 "$root_start" 100%
        fi
    fi
    
    partprobe "$TARGET_DISK"
    sleep 2
}

setup_luks_lvm() {
    if [[ "$LUKS_ENABLE" != "true" ]]; then
        return 0
    fi
    
    log "Setting up LUKS encryption..."
    
    # Create LUKS container
    echo "$LUKS_PASSWORD" | cryptsetup luksFormat "${TARGET_DISK}2"
    echo "$LUKS_PASSWORD" | cryptsetup open "${TARGET_DISK}2" cryptlvm
    
    log "Setting up LVM..."
    
    # Create physical volume
    pvcreate /dev/mapper/cryptlvm
    
    # Create volume group
    vgcreate "$LVM_VG_NAME" /dev/mapper/cryptlvm
    
    # Create logical volumes
    lvcreate -L "$LVM_ROOT_SIZE" -n root "$LVM_VG_NAME"
    lvcreate -L "$LVM_SWAP_SIZE" -n swap "$LVM_VG_NAME"
    
    # Create home volume with remaining space
    lvcreate -l 100%FREE -n home "$LVM_VG_NAME"
}

format_partitions_advanced() {
    log "Formatting partitions..."
    
    # Format EFI partition
    mkfs.fat -F32 "${TARGET_DISK}1"
    
    if [[ "$LUKS_ENABLE" == "true" ]]; then
        # Format LVM logical volumes
        mkfs.ext4 -F "/dev/mapper/$LVM_VG_NAME-root"
        mkfs.ext4 -F "/dev/mapper/$LVM_VG_NAME-home"
        mkswap "/dev/mapper/$LVM_VG_NAME-swap"
        swapon "/dev/mapper/$LVM_VG_NAME-swap"
        
        # Format warehouse partition if it exists
        if [[ "$WAREHOUSE_ENABLE" == "true" && -n "$WAREHOUSE_SIZE" ]]; then
            mkfs.ext4 -F "${TARGET_DISK}3"
        fi
    else
        # Standard formatting
        mkswap "${TARGET_DISK}2"
        swapon "${TARGET_DISK}2"
        mkfs.ext4 -F "${TARGET_DISK}3"
        
        # Format warehouse partition if it exists
        if [[ -n "$WAREHOUSE_SIZE" ]]; then
            mkfs.ext4 -F "${TARGET_DISK}4"
        fi
    fi
}

mount_partitions_advanced() {
    log "Mounting partitions..."
    
    if [[ "$LUKS_ENABLE" == "true" ]]; then
        # Mount LVM volumes
        mount "/dev/mapper/$LVM_VG_NAME-root" /mnt
        mkdir -p /mnt/boot
        mount "${TARGET_DISK}1" /mnt/boot
        mkdir -p /mnt/home
        mount "/dev/mapper/$LVM_VG_NAME-home" /mnt/home
        
        # Mount warehouse partition if it exists
        if [[ "$WAREHOUSE_ENABLE" == "true" && -n "$WAREHOUSE_SIZE" ]]; then
            mkdir -p /mnt/warehouse
            mount "${TARGET_DISK}3" /mnt/warehouse
        fi
    else
        # Standard mounting
        mount "${TARGET_DISK}3" /mnt
        mkdir -p /mnt/boot
        mount "${TARGET_DISK}1" /mnt/boot
        
        # Mount warehouse partition if it exists
        if [[ -n "$WAREHOUSE_SIZE" ]]; then
            mkdir -p /mnt/warehouse
            mount "${TARGET_DISK}4" /mnt/warehouse
        fi
    fi
}

install_base_system() {
    log "Installing base system..."
    
    # Update keyring
    pacman -Sy --noconfirm archlinux-keyring
    
    # Install base packages
    local packages="$BASE_PACKAGES"
    
    # Add desktop environment packages
    if [[ -n "$DESKTOP_ENVIRONMENT" ]]; then
        case "$DESKTOP_ENVIRONMENT" in
            "i3")
                packages="$packages i3-wm i3status i3lock dmenu rofi feh picom alacritty"
                ;;
            "gnome")
                packages="$packages gnome gnome-extra"
                ;;
            "kde")
                packages="$packages plasma kde-applications"
                ;;
            "xfce")
                packages="$packages xfce4 xfce4-goodies"
                ;;
        esac
    fi
    
    # Add NVIDIA packages for RTX 3050 Ti
    packages="$packages nvidia nvidia-utils nvidia-settings nvidia-prime"
    
    # Add Intel graphics packages for Iris Xe
    packages="$packages mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-sdk"
    
    # Add additional packages
    if [[ -n "$ADDITIONAL_PACKAGES" ]]; then
        packages="$packages $ADDITIONAL_PACKAGES"
    fi
    
    pacstrap /mnt $packages
}

generate_fstab_advanced() {
    log "Generating fstab..."
    
    # Generate base fstab
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Add LUKS configuration if enabled
    if [[ "$LUKS_ENABLE" == "true" ]]; then
        local root_uuid=$(blkid -s UUID -o value "${TARGET_DISK}2")
        echo "cryptlvm UUID=$root_uuid none luks,discard" >> /mnt/etc/crypttab
    fi
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

install_bootloader_advanced() {
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
            local root_uuid
            if [[ "$LUKS_ENABLE" == "true" ]]; then
                root_uuid=$(blkid -s UUID -o value "/dev/mapper/$LVM_VG_NAME-root")
            else
                root_uuid=$(blkid -s UUID -o value "${TARGET_DISK}3")
            fi
            
            # Create boot entry
            if [[ "$LUKS_ENABLE" == "true" ]]; then
                local luks_uuid=$(blkid -s UUID -o value "${TARGET_DISK}2")
                cat > /mnt/boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=UUID=$luks_uuid:cryptlvm root=/dev/mapper/$LVM_VG_NAME-root rw
EOF
            else
                cat > /mnt/boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$root_uuid rw
EOF
            fi
            ;;
        "grub")
            arch-chroot /mnt pacman -S --noconfirm grub efibootmgr
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
    esac
}

configure_nvidia_optimus() {
    log "Configuring NVIDIA Optimus..."
    
    # Create NVIDIA configuration
    cat > /mnt/etc/modprobe.d/nvidia.conf << EOF
blacklist nouveau
options nvidia NVreg_UsePageAttributeTable=1
EOF
    
    # Create X11 configuration for Optimus
    mkdir -p /mnt/etc/X11/xorg.conf.d
    cat > /mnt/etc/X11/xorg.conf.d/20-nvidia.conf << EOF
Section "Device"
    Identifier "NVIDIA Card"
    Driver "nvidia"
    VendorName "NVIDIA Corporation"
    BoardName "GeForce RTX 3050 Ti Mobile"
    Option "AllowEmptyInitialConfiguration"
EndSection
EOF
    
    # Configure prime-run for Optimus
    arch-chroot /mnt bash -c "echo 'export __NV_PRIME_RENDER_OFFLOAD=1' >> /etc/environment"
    arch-chroot /mnt bash -c "echo 'export __GLX_VENDOR_LIBRARY_NAME=nvidia' >> /etc/environment"
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

install_cursor_ide() {
    log "Installing Cursor IDE..."
    
    # Install Cursor IDE via AUR
    if [[ "$INSTALL_AUR_HELPER" == "paru" ]]; then
        arch-chroot /mnt su - "$USERNAME" -c "paru -S --noconfirm cursor-bin"
    elif [[ "$INSTALL_AUR_HELPER" == "yay" ]]; then
        arch-chroot /mnt su - "$USERNAME" -c "yay -S --noconfirm cursor-bin"
    else
        warn "AUR helper not available, skipping Cursor IDE installation"
    fi
}

enable_services() {
    log "Enabling services..."
    
    for service in $ENABLE_SERVICES; do
        arch-chroot /mnt systemctl enable "$service"
    done
}

cleanup() {
    log "Cleaning up..."
    
    # Unmount partitions
    umount -R /mnt
    
    # Turn off swap
    swapoff -a
    
    # Close LUKS if open
    if [[ "$LUKS_ENABLE" == "true" ]]; then
        cryptsetup close cryptlvm 2>/dev/null || true
    fi
}

show_completion() {
    log "Installation completed successfully!"
    echo
    echo -e "${GREEN}System Information:${NC}"
    echo "  Hostname: $HOSTNAME"
    echo "  Username: $USERNAME"
    echo "  Desktop: $DESKTOP_ENVIRONMENT"
    echo "  Bootloader: $BOOTLOADER"
    echo "  Encryption: $LUKS_ENABLE"
    echo "  LVM: $LVM_ENABLE"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Remove the installation media"
    echo "  2. Reboot the system"
    echo "  3. Log in with your credentials"
    if [[ "$LUKS_ENABLE" == "true" ]]; then
        echo "  4. Enter LUKS password when prompted"
    fi
    echo
    echo "Installation log saved to: $LOG_FILE"
}

main() {
    log "Starting Advanced Arch Linux automated installation..."
    
    # Check prerequisites
    check_root
    check_network
    
    # Load configuration
    load_config "$1"
    
    # Detect disks
    detect_disks
    
    # Confirmation
    echo
    echo -e "${YELLOW}Installation Summary:${NC}"
    echo "  Target Disk: $TARGET_DISK"
    echo "  Hostname: $HOSTNAME"
    echo "  Username: $USERNAME"
    echo "  Desktop: $DESKTOP_ENVIRONMENT"
    echo "  Bootloader: $BOOTLOADER"
    echo "  Encryption: $LUKS_ENABLE"
    echo "  LVM: $LVM_ENABLE"
    echo
    read -p "Continue with installation? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log "Installation cancelled"
        exit 0
    fi
    
    # Installation steps
    wipe_disk
    create_partitions_advanced
    setup_luks_lvm
    format_partitions_advanced
    mount_partitions_advanced
    install_base_system
    generate_fstab_advanced
    configure_system
    create_user
    install_bootloader_advanced
    configure_nvidia_optimus
    enable_services
    install_aur_helper
    install_cursor_ide
    cleanup
    show_completion
    
    log "Installation completed. Rebooting in 10 seconds..."
    sleep 10
    reboot
}

# Run main function with config file argument
main "$@"
