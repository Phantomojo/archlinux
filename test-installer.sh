#!/bin/bash

# Test Script for Arch Linux Auto Installer
# Tests the installer in a virtual machine environment

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
    echo "  -v, --vm TYPE      Virtual machine type (qemu, virtualbox, vmware)"
    echo "  -i, --iso FILE     Path to ISO file"
    echo "  -m, --memory MB    Memory in MB (default: 2048)"
    echo "  -c, --cores NUM    CPU cores (default: 2)"
    echo "  -s, --storage GB   Storage in GB (default: 20)"
    echo "  -h, --help         Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -v qemu -i archlinux-autoinstall.iso"
    echo "  $0 --vm virtualbox --iso custom.iso --memory 4096"
}

check_dependencies() {
    local vm_type="$1"
    
    log "Checking dependencies for $vm_type..."
    
    case "$vm_type" in
        "qemu")
            if ! command -v qemu-system-x86_64 &> /dev/null; then
                error "qemu-system-x86_64 not found. Please install QEMU."
            fi
            ;;
        "virtualbox")
            if ! command -v VBoxManage &> /dev/null; then
                error "VBoxManage not found. Please install VirtualBox."
            fi
            ;;
        "vmware")
            if ! command -v vmrun &> /dev/null; then
                error "vmrun not found. Please install VMware."
            fi
            ;;
        *)
            error "Unsupported VM type: $vm_type"
            ;;
    esac
}

create_test_config() {
    local config_file="/tmp/test-arch-install.conf"
    
    log "Creating test configuration..."
    
    cat > "$config_file" << 'EOF'
# Test configuration for Arch Linux Auto Installer
HOSTNAME="testarch"
USERNAME="testuser"
USER_PASSWORD="testpass123"
ROOT_PASSWORD="rootpass123"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
KEYMAP="us"
DESKTOP_ENVIRONMENT=""
INSTALL_AUR_HELPER=""
ADDITIONAL_PACKAGES=""
ENABLE_SERVICES="NetworkManager"
BOOTLOADER="systemd-boot"
EFI_SIZE="512M"
SWAP_SIZE="1G"
EOF
    
    echo "$config_file"
}

run_qemu_test() {
    local iso_path="$1"
    local memory="$2"
    local cores="$3"
    local storage="$4"
    
    log "Starting QEMU test..."
    
    # Create test disk
    local test_disk="/tmp/test-arch-disk.qcow2"
    qemu-img create -f qcow2 "$test_disk" "${storage}G"
    
    # Start QEMU
    qemu-system-x86_64 \
        -enable-kvm \
        -m "$memory" \
        -smp "$cores" \
        -drive file="$test_disk",format=qcow2 \
        -cdrom "$iso_path" \
        -boot d \
        -netdev user,id=net0 \
        -device e1000,netdev=net0 \
        -display gtk \
        -name "Arch Linux Auto Installer Test"
    
    log "QEMU test completed"
}

run_virtualbox_test() {
    local iso_path="$1"
    local memory="$2"
    local cores="$3"
    local storage="$4"
    
    log "Starting VirtualBox test..."
    
    local vm_name="ArchAutoInstallerTest"
    
    # Create VM
    VBoxManage createvm --name "$vm_name" --ostype ArchLinux_64 --register
    
    # Configure VM
    VBoxManage modifyvm "$vm_name" --memory "$memory" --cpus "$cores"
    VBoxManage modifyvm "$vm_name" --boot1 dvd --boot2 disk --boot3 none --boot4 none
    
    # Create storage
    VBoxManage createhd --filename "$HOME/VirtualBox VMs/$vm_name/$vm_name.vdi" --size "$((storage * 1024))"
    VBoxManage storagectl "$vm_name" --name "SATA Controller" --add sata --controller IntelAHCI
    VBoxManage storageattach "$vm_name" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/$vm_name/$vm_name.vdi"
    
    # Attach ISO
    VBoxManage storagectl "$vm_name" --name "IDE Controller" --add ide
    VBoxManage storageattach "$vm_name" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$iso_path"
    
    # Start VM
    VBoxManage startvm "$vm_name"
    
    log "VirtualBox test started. VM name: $vm_name"
    log "Use 'VBoxManage controlvm $vm_name poweroff' to stop the VM"
}

run_vmware_test() {
    local iso_path="$1"
    local memory="$2"
    local cores="$3"
    local storage="$4"
    
    log "Starting VMware test..."
    warn "VMware testing requires manual setup. Please create a VM with:"
    echo "  - Memory: ${memory}MB"
    echo "  - CPUs: $cores"
    echo "  - Hard disk: ${storage}GB"
    echo "  - CD/DVD: $iso_path"
    echo "  - Network: NAT"
}

main() {
    local vm_type="qemu"
    local iso_path=""
    local memory=2048
    local cores=2
    local storage=20
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--vm)
                vm_type="$2"
                shift 2
                ;;
            -i|--iso)
                iso_path="$2"
                shift 2
                ;;
            -m|--memory)
                memory="$2"
                shift 2
                ;;
            -c|--cores)
                cores="$2"
                shift 2
                ;;
            -s|--storage)
                storage="$2"
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
    
    # Validate ISO path
    if [[ -z "$iso_path" ]]; then
        error "ISO path is required. Use -i or --iso option."
    fi
    
    if [[ ! -f "$iso_path" ]]; then
        error "ISO file not found: $iso_path"
    fi
    
    # Check dependencies
    check_dependencies "$vm_type"
    
    # Create test configuration
    local config_file=$(create_test_config)
    log "Test configuration created: $config_file"
    
    # Run test based on VM type
    case "$vm_type" in
        "qemu")
            run_qemu_test "$iso_path" "$memory" "$cores" "$storage"
            ;;
        "virtualbox")
            run_virtualbox_test "$iso_path" "$memory" "$cores" "$storage"
            ;;
        "vmware")
            run_vmware_test "$iso_path" "$memory" "$cores" "$storage"
            ;;
    esac
    
    log "Test completed successfully!"
    echo
    echo -e "${YELLOW}Test Results:${NC}"
    echo "  VM Type: $vm_type"
    echo "  ISO: $iso_path"
    echo "  Memory: ${memory}MB"
    echo "  CPUs: $cores"
    echo "  Storage: ${storage}GB"
    echo
    echo -e "${BLUE}Note:${NC} Check the VM to verify the installation completed successfully."
}

# Run main function
main "$@"
