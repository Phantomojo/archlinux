#!/bin/bash

# Arch Linux Auto-Installer for Live USB
# Run this script from the Arch live USB to automatically install Arch Linux

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# WiFi Configuration
WIFI_SSID="WAHOME"
WIFI_PASSWORD="dalial2020"

# Logging
LOG_FILE="/tmp/auto-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

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

show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           🐧 Arch Linux Automated Installer 🐧              ║"
    echo "║                                                              ║"
    echo "║  Fully automated installation with LUKS encryption          ║"
    echo "║  Optimized for Intel i7-12700H + RTX 3050 Ti Mobile        ║"
    echo "║                                                              ║"
    echo "║  WiFi: WAHOME | Target: 1TB Drive | Desktop: i3            ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

setup_wifi() {
    log "Setting up WiFi connection using iwctl..."
    
    # Check if iwctl is available
    if ! command -v iwctl &> /dev/null; then
        error "iwctl not found. Please ensure you're on Arch live USB."
    fi
    
    # Start iwd service
    systemctl start iwd
    
    # Wait for iwd to be ready
    sleep 3
    
    # Get wireless device name
    local device=$(iwctl device list | grep -E "wlan|wlp" | awk '{print $1}' | head -1)
    if [[ -z "$device" ]]; then
        error "No wireless device found"
    fi
    
    log "Found wireless device: $device"
    
    # Connect to WiFi
    log "Connecting to WiFi network: $WIFI_SSID"
    
    # Connect to WiFi
    iwctl station "$device" connect "$WIFI_SSID" --passphrase "$WIFI_PASSWORD"
    
    # Wait for connection
    local attempts=0
    while ! iwctl station "$device" show | grep -q "Connected"; do
        attempts=$((attempts + 1))
        if [[ $attempts -gt 30 ]]; then
            error "Failed to connect to WiFi after 30 attempts"
        fi
        echo -n "."
        sleep 2
    done
    echo
    
    success "Successfully connected to WiFi: $WIFI_SSID"
    
    # Wait for internet connection
    log "Waiting for internet connection..."
    attempts=0
    while ! ping -c 1 archlinux.org &> /dev/null; do
        attempts=$((attempts + 1))
        if [[ $attempts -gt 30 ]]; then
            error "Failed to establish internet connection after 30 attempts"
        fi
        echo -n "."
        sleep 2
    done
    echo
    success "Internet connection established"
}

download_installer() {
    log "Downloading automated installer..."
    
    # Download installer script
    if wget -O install-advanced.sh "https://raw.githubusercontent.com/Phantomojo/archlinux/main/install-advanced.sh"; then
        success "Installer script downloaded successfully"
    else
        error "Failed to download installer script"
    fi
    
    # Download configuration
    if wget -O michael-arch-config.conf "https://raw.githubusercontent.com/Phantomojo/archlinux/main/michael-arch-config.conf"; then
        success "Configuration file downloaded successfully"
    else
        error "Failed to download configuration file"
    fi
    
    # Make installer executable
    chmod +x install-advanced.sh
    
    log "Files ready for installation"
}

show_system_info() {
    log "System Information:"
    echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "  Target Drive: /dev/nvme1n1 (1TB)"
    echo "  WiFi: $WIFI_SSID (connected)"
    echo "  Internet: $(ping -c 1 archlinux.org &> /dev/null && echo "Connected" || echo "Not connected")"
    echo
}

show_installation_plan() {
    log "Installation Plan:"
    echo "  Target Drive: /dev/nvme1n1 (1TB)"
    echo "  Desktop: i3 Window Manager"
    echo "  AUR Helper: paru"
    echo "  Encryption: LUKS-encrypted 100GB root + LVM"
    echo "  Warehouse: ~845GB unencrypted partition"
    echo "  Graphics: NVIDIA RTX 3050 Ti + Intel Iris Xe (Optimus)"
    echo "  Packages: base-devel, git, python, docker, vim, networkmanager"
    echo "  Post-install: Cursor IDE"
    echo "  User: michael (with sudo access)"
    echo
}

run_installer() {
    log "Starting automated installation..."
    echo
    log "This will take 30-60 minutes. Installation will proceed automatically."
    echo
    log "Installation log: $LOG_FILE"
    echo
    
    # Run the installer
    ./install-advanced.sh michael-arch-config.conf
}

main() {
    show_banner
    
    log "Starting fully automated Arch Linux installation..."
    log "This process will:"
    log "1. Connect to WiFi (WAHOME) using iwctl"
    log "2. Download the installer"
    log "3. Install Arch Linux automatically"
    log "4. Reboot into your new system"
    echo
    
    # Setup WiFi
    setup_wifi
    
    # Download installer
    download_installer
    
    # Show system info
    show_system_info
    
    # Show installation plan
    show_installation_plan
    
    # Run installer
    run_installer
    
    success "Installation completed successfully!"
    log "System will reboot in 10 seconds..."
    sleep 10
    reboot
}

# Run main function
main "$@"
