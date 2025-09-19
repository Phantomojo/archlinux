#!/bin/bash

# USB Creation Script for Arch Linux Auto Installer
# Creates a bootable USB with the automated installer

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -i, --iso FILE     Path to ISO file (required)"
    echo "  -d, --device DEV   USB device (e.g., /dev/sdb)"
    echo "  -h, --help         Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -i archlinux-autoinstall-20241219.iso -d /dev/sdb"
    echo "  $0 --iso custom.iso --device /dev/sdc"
}

detect_usb_devices() {
    log "Detecting USB devices..."
    
    local usb_devices=($(lsblk -d -n -o NAME,TYPE,SIZE,TRAN | grep usb | awk '{print $1}'))
    
    if [[ ${#usb_devices[@]} -eq 0 ]]; then
        error "No USB devices found"
    fi
    
    echo "Available USB devices:"
    for i in "${!usb_devices[@]}"; do
        local size=$(lsblk -d -n -o SIZE "/dev/${usb_devices[$i]}")
        echo "  $((i+1)). /dev/${usb_devices[$i]} ($size)"
    done
}

confirm_device() {
    local device="$1"
    
    echo
    warn "WARNING: This will completely erase all data on $device"
    echo "Make sure you have selected the correct device!"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log "Operation cancelled"
        exit 0
    fi
}

write_iso() {
    local iso_path="$1"
    local device="$2"
    
    log "Writing ISO to USB device..."
    log "ISO: $iso_path"
    log "Device: $device"
    
    # Unmount any mounted partitions
    umount "${device}"* 2>/dev/null || true
    
    # Write ISO to device
    dd if="$iso_path" of="$device" bs=4M status=progress oflag=sync
    
    # Sync to ensure data is written
    sync
    
    log "USB creation completed successfully!"
}

verify_usb() {
    local device="$1"
    
    log "Verifying USB device..."
    
    # Check if device exists
    if [[ ! -b "$device" ]]; then
        error "Device $device does not exist"
    fi
    
    # Check if device is mounted
    if mountpoint -q "$device"* 2>/dev/null; then
        warn "Device has mounted partitions. Unmounting..."
        umount "${device}"* 2>/dev/null || true
    fi
}

main() {
    local iso_path=""
    local usb_device=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--iso)
                iso_path="$2"
                shift 2
                ;;
            -d|--device)
                usb_device="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Validate ISO path
    if [[ -z "$iso_path" ]]; then
        error "ISO path is required. Use -i or --iso option."
    fi
    
    if [[ ! -f "$iso_path" ]]; then
        error "ISO file not found: $iso_path"
    fi
    
    # Detect USB device if not provided
    if [[ -z "$usb_device" ]]; then
        detect_usb_devices
        echo
        read -p "Select USB device number: " device_choice
        
        local usb_devices=($(lsblk -d -n -o NAME,TYPE,TRAN | grep usb | awk '{print $1}'))
        if [[ "$device_choice" -ge 1 && "$device_choice" -le ${#usb_devices[@]} ]]; then
            usb_device="/dev/${usb_devices[$((device_choice-1))]}"
        else
            error "Invalid device selection"
        fi
    fi
    
    # Verify and confirm
    verify_usb "$usb_device"
    confirm_device "$usb_device"
    
    # Write ISO
    write_iso "$iso_path" "$usb_device"
    
    echo
    echo -e "${GREEN}USB creation completed successfully!${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Safely remove the USB device"
    echo "  2. Insert USB into target computer"
    echo "  3. Boot from USB"
    echo "  4. Select 'Auto Install Arch Linux' from boot menu"
    echo
    echo -e "${BLUE}Note:${NC} Make sure to configure the installation in the config file"
    echo "before running the installer."
}

# Run main function
main "$@"
