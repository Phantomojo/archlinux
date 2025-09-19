# 🐧 Arch Linux Automated Installer

**Fully automated Arch Linux installer with LUKS encryption, LVM, and optimized for your hardware.**

## 🎯 What This Does

This installer automatically:
- ✅ Partitions your 1TB drive with LUKS encryption
- ✅ Installs i3 window manager + paru AUR helper
- ✅ Configures NVIDIA RTX 3050 Ti + Intel Iris Xe (Optimus)
- ✅ Sets up all essential packages (docker, git, python, etc.)
- ✅ Creates warehouse partition accessible from Ubuntu
- ✅ Installs Cursor IDE post-installation
- ✅ **ZERO manual intervention required**

---

## 🚨 IMPORTANT: READ THIS FIRST

### ⚠️ DESTRUCTIVE OPERATION
- **WILL COMPLETELY WIPE** your 1TB drive (`/dev/nvme1n1`)
- **BACKUP** any important data first
- **TEST** in a virtual machine before real installation

### 🎯 Target System
- **Drive**: 1TB NVMe (`/dev/nvme1n1`)
- **Hardware**: Intel i7-12700H + RTX 3050 Ti Mobile
- **Desktop**: i3 Window Manager
- **Encryption**: LUKS-encrypted 100GB root + LVM

---

## 📋 Quick Start Guide

### Step 1: Download the Installer
```bash
# Clone this repository
git clone https://github.com/Phantomojo/archlinux.git
cd archlinux

# Make scripts executable
chmod +x *.sh
```

### Step 2: Test First (RECOMMENDED)
```bash
# Run validation tests
./test-installer-validation.sh test-config.conf install-advanced.sh

# If all tests pass, you're ready to proceed
```

### Step 3: Boot from Arch Linux Live USB
1. Download latest Arch Linux ISO from [archlinux.org](https://archlinux.org/download/)
2. Create bootable USB with `dd` or tools like Rufus
3. Boot from USB and connect to internet

### Step 4: Run the Installer
```bash
# Download installer to live USB
wget https://raw.githubusercontent.com/Phantomojo/archlinux/main/install-advanced.sh
wget https://raw.githubusercontent.com/Phantomojo/archlinux/main/michael-arch-config.conf

# Make executable
chmod +x install-advanced.sh

# Run the installer
./install-advanced.sh michael-arch-config.conf
```

### Step 5: Wait and Reboot
- Installation takes 30-60 minutes
- Enter LUKS password when prompted
- Login with username: `michael`, password: `ArchLinux2024!`

---

## 🔧 Configuration Options

### Edit Configuration (Optional)
```bash
# Edit the configuration file
nano michael-arch-config.conf

# Key settings you might want to change:
HOSTNAME="michael-arch"           # Your system hostname
USERNAME="michael"                # Your username
USER_PASSWORD="ArchLinux2024!"    # Your password
ROOT_PASSWORD="RootSecure2024!"   # Root password
DESKTOP_ENVIRONMENT="i3"          # i3, gnome, kde, xfce, or empty
INSTALL_AUR_HELPER="paru"         # paru, yay, or empty
```

### Package Customization
```bash
# Add your own packages
ADDITIONAL_PACKAGES="firefox chromium libreoffice steam"

# The installer automatically includes:
# - base-devel, git, python, docker, vim, networkmanager
# - i3 window manager suite
# - NVIDIA drivers for RTX 3050 Ti
# - Intel graphics drivers for Iris Xe
# - Development tools (nodejs, rust, go)
```

---

## 🏗️ What Gets Installed

### Base System
- Arch Linux base system
- Linux kernel with firmware
- NetworkManager for networking
- sudo, vim, nano for system administration

### Desktop Environment
- **i3** - Tiling window manager
- **i3status** - Status bar
- **i3lock** - Screen locker
- **dmenu** - Application launcher
- **rofi** - Advanced launcher
- **feh** - Image viewer/background
- **picom** - Compositor
- **alacritty** - GPU-accelerated terminal

### Graphics Drivers
- **NVIDIA** - RTX 3050 Ti drivers with Optimus support
- **Intel** - Iris Xe graphics drivers
- **Vulkan** - Both Intel and NVIDIA Vulkan support
- **prime-run** - GPU switching support

### Development Tools
- **git** - Version control
- **python** - Python interpreter
- **docker** - Containerization
- **nodejs/npm** - JavaScript development
- **rust** - Rust programming language
- **go** - Go programming language
- **base-devel** - Build tools

### AUR Helper
- **paru** - Fast AUR package manager

### Post-Installation
- **Cursor IDE** - Installed via AUR after base system

---

## 💾 Disk Layout

```
/dev/nvme1n1 (953.9GB - Your 1TB drive)
├── /dev/nvme1n1p1 (512M) - EFI System Partition
├── /dev/nvme1n1p2 (100GB) - LUKS Encrypted Container
│   ├── arch-vg-root (100GB) - Encrypted Root Filesystem
│   ├── arch-vg-swap (8GB) - Encrypted Swap
│   └── arch-vg-home (Remaining) - Encrypted Home
└── /dev/nvme1n1p3 (~845GB) - Warehouse Partition (Unencrypted)
```

### Partition Purposes
- **EFI**: Boot files (512MB)
- **Encrypted Root**: System files, applications (100GB)
- **Encrypted Home**: User data (remaining space in encrypted container)
- **Warehouse**: Shared data accessible from Ubuntu (~845GB)

---

## 🔐 Security Features

### LUKS Encryption
- **100GB encrypted root** - System files protected
- **8GB encrypted swap** - Memory protection
- **Encrypted home** - User data protection
- **Discard support** - SSD optimization

### System Hardening
- **Automatic updates** - Security patches
- **Firewall enabled** - Network protection
- **SSH configured** - Remote access
- **Secure passwords** - Strong authentication

---

## 🎮 NVIDIA Optimus Setup

The installer automatically configures NVIDIA Optimus for your RTX 3050 Ti + Intel Iris Xe setup:

### GPU Switching
```bash
# Use NVIDIA GPU for specific applications
prime-run glxinfo | grep NVIDIA
prime-run steam
prime-run firefox

# Check GPU status
nvidia-smi
```

### Power Management
- Intel GPU for desktop and light tasks (power saving)
- NVIDIA GPU for gaming and heavy workloads (performance)

---

## 🛠️ Troubleshooting

### Installation Fails
1. **Check logs**: `/tmp/arch-advanced-install.log`
2. **Verify network**: `ping archlinux.org`
3. **Check disk**: `lsblk` to confirm target disk
4. **Re-run installer**: Fix issues and try again

### Boot Issues
1. **Check UEFI settings**: Ensure UEFI boot is enabled
2. **Verify bootloader**: Check systemd-boot installation
3. **LUKS password**: Enter correct encryption password
4. **Recovery**: Boot from live USB and chroot

### Graphics Issues
1. **Check drivers**: `nvidia-smi` and `lspci | grep VGA`
2. **Test Optimus**: `prime-run glxinfo | grep NVIDIA`
3. **Reinstall drivers**: `sudo pacman -S nvidia nvidia-utils`

### Network Issues
1. **Check NetworkManager**: `systemctl status NetworkManager`
2. **Configure WiFi**: `nmtui` or `nmcli`
3. **Test connection**: `ping archlinux.org`

---

## 📚 Post-Installation Setup

### First Boot Checklist
- [ ] Enter LUKS password
- [ ] Login with user credentials
- [ ] Verify network: `ping archlinux.org`
- [ ] Check NVIDIA: `nvidia-smi`
- [ ] Test i3: `startx`

### Essential Commands
```bash
# Update system
sudo pacman -Syu

# Install additional software
paru -S firefox chromium steam

# Configure i3
i3-config-wizard

# Start desktop
startx
```

### Cursor IDE Setup
```bash
# Cursor should be installed automatically
# If not, install manually:
paru -S cursor-bin

# Launch Cursor
cursor
```

---

## 🔄 Alternative Installation Methods

### Method 1: Custom ISO (Advanced)
```bash
# Create custom ISO with installer baked in
sudo ./remaster-iso.sh

# Write to USB
sudo ./create-usb.sh -i archlinux-autoinstall-YYYYMMDD.iso -d /dev/sdX

# Boot and select "Auto Install Arch Linux"
```

### Method 2: Virtual Machine Testing
```bash
# Test in VM first
./test-installer.sh -v qemu -i archlinux-latest.iso

# Or with VirtualBox
./test-installer.sh -v virtualbox -i archlinux-latest.iso
```

---

## 📞 Support & Help

### Getting Help
1. **Check logs**: Always check `/tmp/arch-advanced-install.log` first
2. **GitHub Issues**: Report bugs on this repository
3. **ArchWiki**: [wiki.archlinux.org](https://wiki.archlinux.org/)
4. **Arch Forums**: [bbs.archlinux.org](https://bbs.archlinux.org/)

### Common Issues
- **"No internet"**: Configure network before running installer
- **"Disk not found"**: Check `lsblk` output and verify target disk
- **"Installation fails"**: Check logs and verify package availability
- **"Boot issues"**: Verify UEFI settings and bootloader installation

---

## ⚡ Performance Expectations

### Installation Time
- **Base system**: 5-10 minutes
- **Desktop environment**: 10-15 minutes
- **Additional packages**: 15-30 minutes
- **Total**: 30-60 minutes

### System Performance
- **Boot time**: 10-15 seconds (with LUKS)
- **Desktop startup**: 3-5 seconds
- **Application launch**: 1-2 seconds
- **Gaming**: Full RTX 3050 Ti utilization

---

## 🎉 Success Criteria

After successful installation, you should have:
- ✅ **Fully automated installation** - No manual intervention
- ✅ **i3 window manager** - Tiling desktop environment
- ✅ **paru AUR helper** - Package management
- ✅ **LUKS encryption** - 100GB encrypted root
- ✅ **Warehouse partition** - Shared with Ubuntu
- ✅ **NVIDIA Optimus** - RTX 3050 Ti + Iris Xe
- ✅ **Cursor IDE** - Post-installation setup
- ✅ **All essentials** - base-devel, git, python, docker, vim, networkmanager

---

## 📄 Files in This Repository

- **`install-advanced.sh`** - Main installer script
- **`michael-arch-config.conf`** - Your personalized configuration
- **`test-config.conf`** - Test configuration for validation
- **`test-installer-validation.sh`** - Validation and testing script
- **`remaster-iso.sh`** - ISO remastering script
- **`create-usb.sh`** - USB creation utility
- **`test-installer.sh`** - VM testing script
- **`README.md`** - This documentation

---

## 🔗 Links & Resources

- **Arch Linux**: [archlinux.org](https://archlinux.org/)
- **ArchWiki**: [wiki.archlinux.org](https://wiki.archlinux.org/)
- **Installation Guide**: [wiki.archlinux.org/title/Installation_guide](https://wiki.archlinux.org/title/Installation_guide)
- **LUKS Encryption**: [wiki.archlinux.org/title/Dm-crypt](https://wiki.archlinux.org/title/Dm-crypt)
- **NVIDIA Optimus**: [wiki.archlinux.org/title/NVIDIA_Optimus](https://wiki.archlinux.org/title/NVIDIA_Optimus)
- **i3 Window Manager**: [i3wm.org](https://i3wm.org/)

---

**⚠️ Remember**: Always test in a virtual machine first before running on real hardware!

**🚀 Ready to install?** Follow the Quick Start Guide above!