#!/bin/bash

# Quick Install Script for Arch Linux Live USB
# Downloads and runs the automated installer

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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Configuration
INSTALLER_URL="https://raw.githubusercontent.com/Phantomojo/archlinux/main/install-advanced.sh"
CONFIG_URL="https://raw.githubusercontent.com/Phantomojo/archlinux/main/michael-arch-config.conf"
REPO_URL="https://github.com/Phantomojo/archlinux"

show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           🐧 Arch Linux Automated Installer 🐧              ║"
    echo "║                                                              ║"
    echo "║  Fully automated installation with LUKS encryption          ║"
    echo "║  Optimized for Intel i7-12700H + RTX 3050 Ti Mobile        ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_network() {
    log "Checking network connectivity..."
    if ! ping -c 1 archlinux.org &> /dev/null; then
        error "No internet connection. Please configure network first."
    fi
    log "Network connectivity confirmed"
}

download_installer() {
    log "Downloading automated installer..."
    
    # Download installer script
    if wget -O install-advanced.sh "$INSTALLER_URL"; then
        success "Installer script downloaded successfully"
    else
        error "Failed to download installer script"
    fi
    
    # Download configuration
    if wget -O michael-arch-config.conf "$CONFIG_URL"; then
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
    echo "  Disks:"
    lsblk -d -n -o NAME,SIZE,TYPE | grep disk | while read -r line; do
        echo "    $line"
    done
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
    echo
}

confirm_installation() {
    warn "⚠️  WARNING: This will completely wipe /dev/nvme1n1 (1TB drive)"
    warn "⚠️  Make sure you have backed up any important data"
    echo
    read -p "Do you want to continue with the installation? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log "Installation cancelled"
        exit 0
    fi
}

run_installer() {
    log "Starting automated installation..."
    echo
    log "This will take 30-60 minutes. You can monitor progress in the terminal."
    echo
    read -p "Press Enter to start installation..."
    
    # Run the installer
    ./install-advanced.sh michael-arch-config.conf
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -i, --info     Show system information only"
    echo "  -d, --download Download files only (don't install)"
    echo
    echo "This script downloads and runs the Arch Linux automated installer."
    echo "Repository: $REPO_URL"
}

main() {
    local show_info_only=false
    local download_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--info)
                show_info_only=true
                shift
                ;;
            -d|--download)
                download_only=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Show banner
    show_banner
    
    # Check network
    check_network
    
    # Show system info
    show_system_info
    
    if [[ "$show_info_only" == true ]]; then
        log "System information displayed. Exiting."
        exit 0
    fi
    
    # Download installer
    download_installer
    
    if [[ "$download_only" == true ]]; then
        log "Files downloaded successfully. Exiting."
        exit 0
    fi
    
    # Show installation plan
    show_installation_plan
    
    # Confirm installation
    confirm_installation
    
    # Run installer
    run_installer
}

# Run main function
main "$@"
