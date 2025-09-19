#!/bin/bash

# Create Auto-Install USB Script
# Modifies the live USB to auto-connect to WiFi and run installer

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

# Configuration
USB_DEVICE=""
USB_MOUNT="/mnt/usb"
AUTO_SCRIPT="auto-install-iwctl.sh"

detect_usb() {
    log "Detecting Arch Linux live USB..."
    
    # Find mounted Arch USB
    local arch_usb=$(mount | grep "ARCH_202509" | awk '{print $1}' | head -1)
    if [[ -n "$arch_usb" ]]; then
        USB_DEVICE="$arch_usb"
        USB_MOUNT=$(mount | grep "ARCH_202509" | awk '{print $3}' | head -1)
        log "Found Arch USB: $USB_DEVICE mounted at $USB_MOUNT"
        return 0
    fi
    
    # If not mounted, try to find USB devices
    local usb_devices=($(lsblk -d -n -o NAME,TYPE,SIZE,TRAN | grep usb | awk '{print $1}'))
    
    if [[ ${#usb_devices[@]} -eq 0 ]]; then
        error "No USB devices found"
    fi
    
    echo "Available USB devices:"
    for i in "${!usb_devices[@]}"; do
        local size=$(lsblk -d -n -o SIZE "/dev/${usb_devices[$i]}")
        echo "  $((i+1)). /dev/${usb_devices[$i]} ($size)"
    done
    
    read -p "Select USB device number: " device_choice
    if [[ "$device_choice" -ge 1 && "$device_choice" -le ${#usb_devices[@]} ]]; then
        USB_DEVICE="/dev/${usb_devices[$((device_choice-1))]}"
    else
        error "Invalid device selection"
    fi
}

create_auto_script() {
    log "Creating auto-install script for USB..."
    
    # Create a simple script that can be copied to USB
    cat > usb-auto-install.sh << 'EOF'
#!/bin/bash

# Auto-install script for Arch Linux live USB
# This script runs automatically when the USB boots

set -euo pipefail

# WiFi Configuration
WIFI_SSID="WAHOME"
WIFI_PASSWORD="dalial2020"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Wait for system to be ready
sleep 10

log "Arch Linux Auto-Installer Starting..."

# Connect to WiFi using iwctl
log "Connecting to WiFi: $WIFI_SSID"
systemctl start iwd
sleep 3

# Get wireless device
device=$(iwctl device list | grep -E "wlan|wlp" | awk '{print $1}' | head -1)
if [[ -z "$device" ]]; then
    error "No wireless device found"
fi

# Connect to WiFi
iwctl station "$device" connect "$WIFI_SSID" --passphrase "$WIFI_PASSWORD"

# Wait for connection
attempts=0
while ! iwctl station "$device" show | grep -q "Connected"; do
    attempts=$((attempts + 1))
    if [[ $attempts -gt 30 ]]; then
        error "Failed to connect to WiFi"
    fi
    sleep 2
done

log "WiFi connected successfully"

# Wait for internet
attempts=0
while ! ping -c 1 archlinux.org &> /dev/null; do
    attempts=$((attempts + 1))
    if [[ $attempts -gt 30 ]]; then
        error "No internet connection"
    fi
    sleep 2
done

log "Internet connection established"

# Download and run installer
log "Downloading installer..."
wget -O install-advanced.sh "https://raw.githubusercontent.com/Phantomojo/archlinux/main/install-advanced.sh"
wget -O michael-arch-config.conf "https://raw.githubusercontent.com/Phantomojo/archlinux/main/michael-arch-config.conf"

chmod +x install-advanced.sh

log "Starting installation..."
./install-advanced.sh michael-arch-config.conf
EOF

    chmod +x usb-auto-install.sh
    log "Auto-install script created: usb-auto-install.sh"
}

copy_to_usb() {
    log "Copying auto-install script to USB..."
    
    # Check if USB is mounted
    if [[ -z "$USB_MOUNT" ]]; then
        # Mount USB
        mkdir -p /tmp/usb-mount
        mount "$USB_DEVICE"1 /tmp/usb-mount
        USB_MOUNT="/tmp/usb-mount"
    fi
    
    # Copy script to USB
    if cp usb-auto-install.sh "$USB_MOUNT/"; then
        success "Auto-install script copied to USB"
    else
        error "Failed to copy script to USB"
    fi
    
    # Create a simple launcher
    cat > "$USB_MOUNT/run-auto-install.sh" << 'EOF'
#!/bin/bash
echo "Starting Arch Linux Auto-Installer..."
echo "This will connect to WiFi and install Arch Linux automatically"
echo "Press Ctrl+C to cancel within 10 seconds..."
sleep 10
./usb-auto-install.sh
EOF
    
    chmod +x "$USB_MOUNT/run-auto-install.sh"
    
    # Create instructions file
    cat > "$USB_MOUNT/README.txt" << 'EOF'
🐧 ARCH LINUX AUTO-INSTALLER USB 🐧

This USB will automatically:
1. Connect to WiFi (WAHOME)
2. Download the installer
3. Install Arch Linux on /dev/nvme1n1 (1TB drive)
4. Reboot into your new system

TO USE:
1. Boot from this USB
2. Run: ./run-auto-install.sh
3. Wait 30-60 minutes
4. Enjoy your new Arch system!

WARNING: This will wipe /dev/nvme1n1 completely!

WiFi: WAHOME (password: dalial2020)
Target: 1TB drive (/dev/nvme1n1)
Desktop: i3 + paru + LUKS encryption
EOF
    
    log "USB setup completed successfully"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -d, --device DEV   USB device (e.g., /dev/sdb)"
    echo "  -h, --help         Show this help message"
    echo
    echo "This script modifies your Arch Linux live USB to auto-connect to WiFi"
    echo "and run the automated installer."
}

main() {
    local usb_device=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
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
    
    log "Creating auto-install USB..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Detect USB
    if [[ -n "$usb_device" ]]; then
        USB_DEVICE="$usb_device"
    else
        detect_usb
    fi
    
    # Create auto-install script
    create_auto_script
    
    # Copy to USB
    copy_to_usb
    
    log "Auto-install USB created successfully!"
    echo
    echo -e "${GREEN}Your USB is now ready for automatic installation!${NC}"
    echo
    echo -e "${YELLOW}To use:${NC}"
    echo "1. Boot from this USB"
    echo "2. Run: ./run-auto-install.sh"
    echo "3. Wait for installation to complete"
    echo
    echo -e "${BLUE}The USB will automatically:${NC}"
    echo "- Connect to WiFi (WAHOME)"
    echo "- Download the installer"
    echo "- Install Arch Linux on your 1TB drive"
    echo "- Reboot into your new system"
}

# Run main function
main "$@"
