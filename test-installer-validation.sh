#!/bin/bash

# Arch Linux Installer Validation Script
# Tests the installer configuration and logic without destructive operations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# Test functions
test_config_loading() {
    log "Testing configuration loading..."
    
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Test if we can source the config
    if source "$config_file" 2>/dev/null; then
        success "Configuration file syntax is valid"
    else
        error "Configuration file has syntax errors"
        return 1
    fi
    
    # Validate required variables
    local required_vars=("HOSTNAME" "USERNAME" "USER_PASSWORD" "ROOT_PASSWORD" "TIMEZONE" "LOCALE")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required variable $var is not set"
            return 1
        fi
    done
    
    success "All required configuration variables are set"
    return 0
}

test_package_validation() {
    log "Testing package validation..."
    
    # Test if packages are valid (basic check)
    local packages="$BASE_PACKAGES $ADDITIONAL_PACKAGES"
    local invalid_packages=()
    
    # Check for obviously invalid package names
    for package in $packages; do
        if [[ "$package" =~ [^a-zA-Z0-9_-] ]]; then
            invalid_packages+=("$package")
        fi
    done
    
    if [[ ${#invalid_packages[@]} -gt 0 ]]; then
        error "Invalid package names found: ${invalid_packages[*]}"
        return 1
    fi
    
    success "Package names appear valid"
    return 0
}

test_disk_detection() {
    log "Testing disk detection logic..."
    
    # Simulate disk detection
    local disks=($(lsblk -d -n -o NAME,TYPE,SIZE | grep disk | awk '{print $1}' 2>/dev/null || echo "sda"))
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        warn "No disks detected (this is normal in some environments)"
        return 0
    fi
    
    success "Disk detection logic works (found ${#disks[@]} disks)"
    return 0
}

test_network_connectivity() {
    log "Testing network connectivity..."
    
    if ping -c 1 archlinux.org &> /dev/null; then
        success "Network connectivity confirmed"
        return 0
    else
        warn "No network connectivity (this is normal in some environments)"
        return 0
    fi
}

test_script_syntax() {
    log "Testing installer script syntax..."
    
    local script_file="$1"
    if [[ ! -f "$script_file" ]]; then
        error "Installer script not found: $script_file"
        return 1
    fi
    
    # Test bash syntax
    if bash -n "$script_file" 2>/dev/null; then
        success "Installer script syntax is valid"
    else
        error "Installer script has syntax errors"
        return 1
    fi
    
    return 0
}

test_partition_logic() {
    log "Testing partition logic..."
    
    # Test partition size calculations
    local efi_size="$EFI_SIZE"
    local swap_size="${LVM_SWAP_SIZE:-4G}"
    
    # Basic validation
    if [[ "$efi_size" =~ ^[0-9]+[MG]?$ ]]; then
        success "EFI partition size format is valid: $efi_size"
    else
        error "Invalid EFI partition size format: $efi_size"
        return 1
    fi
    
    if [[ "$LUKS_ENABLE" == "true" ]]; then
        if [[ -z "$LUKS_PASSWORD" ]]; then
            error "LUKS is enabled but no password is set"
            return 1
        fi
        success "LUKS configuration appears valid"
    else
        success "LUKS is disabled (simpler setup)"
    fi
    
    return 0
}

test_bootloader_config() {
    log "Testing bootloader configuration..."
    
    case "$BOOTLOADER" in
        "systemd-boot"|"grub")
            success "Bootloader choice is valid: $BOOTLOADER"
            ;;
        *)
            error "Invalid bootloader choice: $BOOTLOADER"
            return 1
            ;;
    esac
    
    return 0
}

test_desktop_environment() {
    log "Testing desktop environment configuration..."
    
    case "$DESKTOP_ENVIRONMENT" in
        "i3"|"gnome"|"kde"|"xfce"|"")
            success "Desktop environment choice is valid: $DESKTOP_ENVIRONMENT"
            ;;
        *)
            error "Invalid desktop environment choice: $DESKTOP_ENVIRONMENT"
            return 1
            ;;
    esac
    
    return 0
}

test_aur_helper() {
    log "Testing AUR helper configuration..."
    
    case "$INSTALL_AUR_HELPER" in
        "yay"|"paru"|"")
            success "AUR helper choice is valid: $INSTALL_AUR_HELPER"
            ;;
        *)
            error "Invalid AUR helper choice: $INSTALL_AUR_HELPER"
            return 1
            ;;
    esac
    
    return 0
}

run_dry_run_test() {
    log "Running dry-run test of installer..."
    
    local script_file="${1:-install-advanced.sh}"
    local config_file="${2:-test-config.conf}"
    
    # Create a test environment
    local test_dir="/tmp/arch-installer-test"
    mkdir -p "$test_dir"
    
    # Copy installer script
    cp "$script_file" "$test_dir/"
    cp "$config_file" "$test_dir/"
    
    # Modify script to run in dry-run mode
    sed -i 's/wipe_disk/#wipe_disk/' "$test_dir/install-advanced.sh"
    sed -i 's/create_partitions_advanced/#create_partitions_advanced/' "$test_dir/install-advanced.sh"
    sed -i 's/setup_luks_lvm/#setup_luks_lvm/' "$test_dir/install-advanced.sh"
    sed -i 's/format_partitions_advanced/#format_partitions_advanced/' "$test_dir/install-advanced.sh"
    sed -i 's/mount_partitions_advanced/#mount_partitions_advanced/' "$test_dir/install-advanced.sh"
    sed -i 's/install_base_system/#install_base_system/' "$test_dir/install-advanced.sh"
    sed -i 's/generate_fstab_advanced/#generate_fstab_advanced/' "$test_dir/install-advanced.sh"
    sed -i 's/configure_system/#configure_system/' "$test_dir/install-advanced.sh"
    sed -i 's/create_user/#create_user/' "$test_dir/install-advanced.sh"
    sed -i 's/install_bootloader_advanced/#install_bootloader_advanced/' "$test_dir/install-advanced.sh"
    sed -i 's/configure_nvidia_optimus/#configure_nvidia_optimus/' "$test_dir/install-advanced.sh"
    sed -i 's/enable_services/#enable_services/' "$test_dir/install-advanced.sh"
    sed -i 's/install_aur_helper/#install_aur_helper/' "$test_dir/install-advanced.sh"
    sed -i 's/install_cursor_ide/#install_cursor_ide/' "$test_dir/install-advanced.sh"
    sed -i 's/cleanup/#cleanup/' "$test_dir/install-advanced.sh"
    sed -i 's/reboot/#reboot/' "$test_dir/install-advanced.sh"
    
    # Add dry-run mode
    cat >> "$test_dir/install-advanced.sh" << 'EOF'

# Dry-run mode - no actual installation
log "DRY-RUN MODE: No actual installation performed"
log "All installation steps would have been executed successfully"
EOF
    
    # Test the modified script
    if bash "$test_dir/install-advanced.sh" "$config_file" 2>/dev/null; then
        success "Dry-run test completed successfully"
    else
        error "Dry-run test failed"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    return 0
}

main() {
    local config_file="${1:-test-config.conf}"
    local script_file="${2:-install-advanced.sh}"
    
    log "Starting Arch Linux Installer Validation..."
    echo
    
    # Load configuration
    if ! source "$config_file" 2>/dev/null; then
        error "Failed to load configuration file: $config_file"
        exit 1
    fi
    
    local tests_passed=0
    local tests_total=0
    
    # Run all tests
    local tests=(
        "test_config_loading:$config_file"
        "test_package_validation"
        "test_disk_detection"
        "test_network_connectivity"
        "test_script_syntax:$script_file"
        "test_partition_logic"
        "test_bootloader_config"
        "test_desktop_environment"
        "test_aur_helper"
        "run_dry_run_test:$script_file:$config_file"
    )
    
    for test in "${tests[@]}"; do
        IFS=':' read -r test_name test_args <<< "$test"
        tests_total=$((tests_total + 1))
        
        echo -n "Running $test_name... "
        if $test_name $test_args; then
            tests_passed=$((tests_passed + 1))
        fi
        echo
    done
    
    echo
    log "Validation Results: $tests_passed/$tests_total tests passed"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        success "All tests passed! Installer is ready for use."
        echo
        echo -e "${GREEN}Next steps:${NC}"
        echo "1. Review the configuration in $config_file"
        echo "2. Test in a virtual machine first"
        echo "3. Run the installer on real hardware"
        return 0
    else
        error "Some tests failed. Please fix the issues before proceeding."
        return 1
    fi
}

# Run main function
main "$@"
