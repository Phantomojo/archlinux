#!/bin/bash

# Arch Linux ISO Remastering Script
# Creates a custom Arch ISO with automated installer

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARCH_ISO_URL="https://mirror.rackspace.com/archlinux/iso/latest/"
WORK_DIR="/tmp/arch-remaster"
MOUNT_DIR="$WORK_DIR/mount"
EXTRACT_DIR="$WORK_DIR/extract"
CUSTOM_ISO_DIR="$WORK_DIR/custom"

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

check_dependencies() {
    log "Checking dependencies..."
    
    local deps=("wget" "7z" "xorriso" "arch-install-scripts")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Required dependency '$dep' not found. Please install it first."
        fi
    done
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

download_iso() {
    log "Downloading latest Arch Linux ISO..."
    
    # Get the latest ISO filename
    local iso_filename=$(wget -qO- "$ARCH_ISO_URL" | grep -oP 'archlinux-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-x86_64\.iso' | head -1)
    
    if [[ -z "$iso_filename" ]]; then
        error "Could not determine latest ISO filename"
    fi
    
    local iso_url="$ARCH_ISO_URL$iso_filename"
    local iso_path="$WORK_DIR/$iso_filename"
    
    if [[ ! -f "$iso_path" ]]; then
        log "Downloading $iso_filename..."
        wget -O "$iso_path" "$iso_url"
    else
        log "ISO already exists: $iso_path"
    fi
    
    echo "$iso_path"
}

extract_iso() {
    local iso_path="$1"
    
    log "Extracting ISO contents..."
    
    # Create work directories
    mkdir -p "$EXTRACT_DIR" "$MOUNT_DIR"
    
    # Mount the ISO
    mount -o loop "$iso_path" "$MOUNT_DIR"
    
    # Copy contents
    cp -r "$MOUNT_DIR"/* "$EXTRACT_DIR/"
    
    # Unmount
    umount "$MOUNT_DIR"
    
    log "ISO extracted to $EXTRACT_DIR"
}

inject_installer() {
    log "Injecting automated installer..."
    
    # Copy installer script
    cp "$(dirname "$0")/install.sh" "$EXTRACT_DIR/usr/local/bin/"
    chmod +x "$EXTRACT_DIR/usr/local/bin/install.sh"
    
    # Copy configuration template
    cp "$(dirname "$0")/arch-install.conf.example" "$EXTRACT_DIR/usr/local/bin/"
    
    # Create auto-start script
    cat > "$EXTRACT_DIR/usr/local/bin/auto-install.sh" << 'EOF'
#!/bin/bash

# Auto-start script for automated installation
# This runs automatically when the ISO boots

set -euo pipefail

LOG_FILE="/tmp/auto-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

echo "Arch Linux Automated Installer - Auto-start"
echo "=========================================="

# Wait for network
echo "Waiting for network connection..."
for i in {1..30}; do
    if ping -c 1 archlinux.org &> /dev/null; then
        echo "Network connection established"
        break
    fi
    echo "Attempt $i/30..."
    sleep 2
done

# Check if we should run the installer
if [[ -f "/usr/local/bin/install.sh" ]]; then
    echo "Starting automated installation..."
    echo "Press Ctrl+C within 10 seconds to cancel..."
    sleep 10
    
    # Run the installer
    /usr/local/bin/install.sh
else
    echo "Installer script not found. Dropping to shell."
    bash
fi
EOF
    
    chmod +x "$EXTRACT_DIR/usr/local/bin/auto-install.sh"
}

create_autostart_service() {
    log "Creating autostart systemd service..."
    
    # Create systemd service
    cat > "$EXTRACT_DIR/etc/systemd/system/auto-install.service" << 'EOF'
[Unit]
Description=Arch Linux Automated Installer
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-install.sh
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    mkdir -p "$EXTRACT_DIR/etc/systemd/system/multi-user.target.wants"
    ln -sf "/etc/systemd/system/auto-install.service" \
          "$EXTRACT_DIR/etc/systemd/system/multi-user.target.wants/auto-install.service"
}

modify_boot_config() {
    log "Modifying boot configuration..."
    
    # Add auto-install option to boot menu
    local isolinux_cfg="$EXTRACT_DIR/isolinux/isolinux.cfg"
    if [[ -f "$isolinux_cfg" ]]; then
        # Backup original
        cp "$isolinux_cfg" "$isolinux_cfg.backup"
        
        # Add auto-install option
        cat >> "$isolinux_cfg" << 'EOF'

label autoinstall
menu label ^Auto Install Arch Linux
kernel /arch/boot/x86_64/vmlinuz-linux
initrd /arch/boot/x86_64/initramfs-linux.img
append archisobasedir=arch archisolabel=ARCH_$(date +%Y%m) autoinstall
EOF
    fi
    
    # Modify EFI boot configuration
    local grub_cfg="$EXTRACT_DIR/EFI/arch/grub.cfg"
    if [[ -f "$grub_cfg" ]]; then
        # Backup original
        cp "$grub_cfg" "$grub_cfg.backup"
        
        # Add auto-install menu entry
        sed -i '/^menuentry/a\
menuentry "Auto Install Arch Linux" {\
    linux /arch/boot/x86_64/vmlinuz-linux archisobasedir=arch archisolabel=ARCH_$(date +%Y%m) autoinstall\
    initrd /arch/boot/x86_64/initramfs-linux.img\
}' "$grub_cfg"
    fi
}

create_custom_iso() {
    local iso_path="$1"
    local custom_iso_name="archlinux-autoinstall-$(date +%Y%m%d).iso"
    local custom_iso_path="$WORK_DIR/$custom_iso_name"
    
    log "Creating custom ISO: $custom_iso_name"
    
    # Create ISO using xorriso
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "ARCH_$(date +%Y%m)" \
        -appid "Arch Linux Auto Installer" \
        -publisher "Arch Linux Auto Installer" \
        -preparer "prepared by arch-auto-installer" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr /usr/lib/syslinux/bios/isohdpfx.bin \
        -eltorito-alt-boot \
        -e EFI/archiso/efiboot.img \
        -no-emul-boot -isohybrid-gpt-basdat \
        -output "$custom_iso_path" \
        "$EXTRACT_DIR"
    
    log "Custom ISO created: $custom_iso_path"
    echo "$custom_iso_path"
}

cleanup() {
    log "Cleaning up..."
    
    # Unmount if still mounted
    if mountpoint -q "$MOUNT_DIR"; then
        umount "$MOUNT_DIR"
    fi
    
    # Remove work directory
    rm -rf "$WORK_DIR"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -k, --keep     Keep work directory after completion"
    echo
    echo "This script creates a custom Arch Linux ISO with automated installer."
    echo "The resulting ISO will automatically start the installation process."
}

main() {
    local keep_workdir=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -k|--keep)
                keep_workdir=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    log "Starting Arch Linux ISO remastering..."
    
    # Check dependencies
    check_dependencies
    
    # Download ISO
    local iso_path=$(download_iso)
    
    # Extract ISO
    extract_iso "$iso_path"
    
    # Inject installer
    inject_installer
    
    # Create autostart service
    create_autostart_service
    
    # Modify boot configuration
    modify_boot_config
    
    # Create custom ISO
    local custom_iso_path=$(create_custom_iso "$iso_path")
    
    # Cleanup
    if [[ "$keep_workdir" == false ]]; then
        cleanup
    fi
    
    log "Remastering completed successfully!"
    echo
    echo -e "${GREEN}Custom ISO created:${NC} $custom_iso_path"
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo "  1. Write the ISO to a USB drive:"
    echo "     dd if=$custom_iso_path of=/dev/sdX bs=4M status=progress"
    echo
    echo "  2. Boot from the USB drive"
    echo "  3. Select 'Auto Install Arch Linux' from the boot menu"
    echo "  4. The installation will start automatically"
    echo
    echo -e "${BLUE}Note:${NC} You can modify the configuration by editing:"
    echo "  /usr/local/bin/arch-install.conf.example on the ISO"
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
