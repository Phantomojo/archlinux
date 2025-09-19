# Arch Linux Automated Installer - Installation Guide

This guide provides step-by-step instructions for using the Arch Linux Automated Installer.

## Prerequisites

### System Requirements

- **Target System**: x86_64 architecture
- **Memory**: Minimum 2GB RAM (4GB recommended)
- **Storage**: Minimum 20GB free space
- **Network**: Internet connection required
- **Boot Mode**: UEFI or Legacy BIOS support

### Required Tools

For manual installation:
- Arch Linux live USB
- Internet connection

For ISO remastering:
- Linux system with root access
- Required packages: `wget`, `7z`, `xorriso`, `arch-install-scripts`

## Installation Methods

### Method 1: Manual Script Installation

1. **Prepare the Live Environment**
   ```bash
   # Boot from Arch Linux live USB
   # Connect to internet
   ping -c 1 archlinux.org
   ```

2. **Download the Installer**
   ```bash
   # Download the installer script
   wget https://raw.githubusercontent.com/yourusername/arch-auto-installer/main/install.sh
   chmod +x install.sh
   
   # Download configuration template
   wget https://raw.githubusercontent.com/yourusername/arch-auto-installer/main/arch-install.conf.example
   ```

3. **Configure the Installation**
   ```bash
   # Copy and edit configuration
   cp arch-install.conf.example arch-install.conf
   nano arch-install.conf
   ```

4. **Run the Installer**
   ```bash
   # Run with configuration file
   ./install.sh arch-install.conf
   
   # Or run interactively
   ./install.sh
   ```

### Method 2: Custom ISO Installation (Recommended)

1. **Create Custom ISO**
   ```bash
   # Clone the repository
   git clone https://github.com/yourusername/arch-auto-installer.git
   cd arch-auto-installer
   
   # Create custom ISO
   sudo ./remaster-iso.sh
   ```

2. **Create Bootable USB**
   ```bash
   # Write ISO to USB
   sudo ./create-usb.sh -i archlinux-autoinstall-YYYYMMDD.iso -d /dev/sdX
   
   # Or manually with dd
   sudo dd if=archlinux-autoinstall-YYYYMMDD.iso of=/dev/sdX bs=4M status=progress
   ```

3. **Boot and Install**
   - Insert USB into target computer
   - Boot from USB
   - Select "Auto Install Arch Linux" from boot menu
   - Wait for installation to complete

## Configuration Options

### Basic Configuration

```bash
# System identification
HOSTNAME="myarch"
USERNAME="myuser"
USER_PASSWORD="mypassword"
ROOT_PASSWORD="rootpass"

# Localization
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"
```

### Desktop Environment

```bash
# Choose one desktop environment
DESKTOP_ENVIRONMENT="gnome"    # GNOME desktop
DESKTOP_ENVIRONMENT="kde"      # KDE Plasma
DESKTOP_ENVIRONMENT="xfce"     # XFCE (lightweight)
DESKTOP_ENVIRONMENT="i3"       # i3 window manager
DESKTOP_ENVIRONMENT=""         # No desktop (server)
```

### Package Management

```bash
# AUR helper
INSTALL_AUR_HELPER="yay"       # Yet Another Yaourt
INSTALL_AUR_HELPER="paru"      # Fast AUR helper
INSTALL_AUR_HELPER=""          # No AUR helper

# Additional packages
ADDITIONAL_PACKAGES="firefox chromium git vim"
```

### Bootloader

```bash
# Bootloader choice
BOOTLOADER="systemd-boot"      # systemd-boot (UEFI)
BOOTLOADER="grub"              # GRUB (BIOS/UEFI)
```

### Partition Layout

```bash
# Partition sizes
EFI_SIZE="512M"                # EFI system partition
SWAP_SIZE="4G"                 # Swap partition
ROOT_SIZE=""                   # Root partition (empty = remaining space)
```

## Advanced Configuration

### Custom Package Lists

```bash
# Base packages (always installed)
BASE_PACKAGES="base linux linux-firmware sudo vim nano networkmanager"

# Development packages
DEV_PACKAGES="git base-devel"

# Desktop-specific packages
DESKTOP_PACKAGES="firefox chromium libreoffice"
```

### Service Configuration

```bash
# Services to enable
ENABLE_SERVICES="NetworkManager sshd"
```

### Network Configuration

The installer automatically configures NetworkManager. For custom network settings, modify the configuration after installation.

## Installation Process

### What the Installer Does

1. **Disk Preparation**
   - Detects available disks
   - Wipes target disk
   - Creates GPT partition table
   - Creates EFI, swap, and root partitions

2. **Filesystem Setup**
   - Formats EFI partition (FAT32)
   - Formats swap partition
   - Formats root partition (ext4)
   - Mounts partitions

3. **Base System Installation**
   - Updates package keyring
   - Installs base packages with pacstrap
   - Generates fstab

4. **System Configuration**
   - Sets timezone and locale
   - Configures hostname
   - Creates user accounts
   - Sets passwords

5. **Bootloader Installation**
   - Installs systemd-boot or GRUB
   - Configures boot entries
   - Sets up EFI boot

6. **Service Configuration**
   - Enables NetworkManager
   - Enables other specified services

7. **Optional Components**
   - Installs desktop environment
   - Installs AUR helper
   - Installs additional packages

8. **Finalization**
   - Cleans up and unmounts
   - Displays completion information
   - Reboots system

### Installation Time

- **Minimal installation**: 5-10 minutes
- **With desktop environment**: 15-30 minutes
- **With additional packages**: 30-60 minutes

## Post-Installation

### First Boot

1. **Remove Installation Media**
   - Remove USB drive
   - Boot from hard disk

2. **Login**
   - Use configured username and password
   - Or login as root with root password

3. **Verify Installation**
   ```bash
   # Check system information
   uname -a
   hostnamectl
   
   # Check network
   ip addr
   ping -c 1 archlinux.org
   
   # Check services
   systemctl status NetworkManager
   ```

### Initial Setup

1. **Update System**
   ```bash
   sudo pacman -Syu
   ```

2. **Install Additional Software**
   ```bash
   # Using pacman
   sudo pacman -S firefox chromium
   
   # Using AUR helper (if installed)
   yay -S visual-studio-code-bin
   ```

3. **Configure Desktop Environment**
   - Start desktop environment
   - Configure display settings
   - Install additional applications

## Troubleshooting

### Common Issues

1. **Installation Fails**
   - Check installation log: `/tmp/arch-install.log`
   - Verify network connection
   - Check disk space
   - Verify package availability

2. **Boot Issues**
   - Check UEFI/BIOS settings
   - Verify bootloader installation
   - Check partition table
   - Verify EFI partition

3. **Network Issues**
   - Check NetworkManager status
   - Verify network configuration
   - Check firewall settings

4. **Desktop Environment Issues**
   - Check display manager
   - Verify graphics drivers
   - Check X11/Wayland configuration

### Recovery

If installation fails:

1. **Boot from Live USB**
   ```bash
   # Mount target system
   mount /dev/sda3 /mnt
   mount /dev/sda1 /mnt/boot
   
   # Chroot into system
   arch-chroot /mnt
   ```

2. **Fix Issues**
   - Review logs
   - Reinstall packages
   - Fix configuration

3. **Continue Installation**
   - Re-run installer
   - Or continue manually

### Logs

Installation logs are available at:
- `/tmp/arch-install.log` - Main installation log
- `/var/log/pacman.log` - Package installation log
- `journalctl` - System journal

## Security Considerations

### Password Security

- Use strong passwords
- Consider using password managers
- Enable two-factor authentication where possible

### System Hardening

1. **Firewall**
   ```bash
   sudo pacman -S ufw
   sudo ufw enable
   ```

2. **SSH Security**
   ```bash
   sudo pacman -S openssh
   sudo systemctl enable sshd
   # Configure SSH keys
   ```

3. **Automatic Updates**
   ```bash
   sudo pacman -S unattended-upgrades
   ```

### Backup

- Create system backups
- Use version control for configuration files
- Document custom configurations

## Support

### Getting Help

1. **Check Documentation**
   - README.md
   - ArchWiki
   - Official Arch Linux documentation

2. **Community Support**
   - GitHub Issues
   - Arch Linux Forums
   - IRC Channels

3. **Debugging**
   - Enable verbose logging
   - Check system logs
   - Use debugging tools

### Contributing

- Report bugs
- Suggest improvements
- Submit pull requests
- Help with documentation

---

**Important**: Always test the installer in a virtual machine before using it on production systems. The installer will completely wipe the target disk.
