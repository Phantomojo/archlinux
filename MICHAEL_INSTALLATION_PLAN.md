# Michael's Arch Linux Installation Plan
## Mission Brief: Fully Automated Arch Installer for 1TB Drive

### 🎯 Mission Objectives
- **Target**: 1TB NVMe drive (`/dev/nvme1n1`)
- **Desktop**: i3 Window Manager
- **AUR Helper**: paru
- **Encryption**: LUKS-encrypted 100GB root + LVM
- **Warehouse**: Large unencrypted partition accessible from Ubuntu
- **Hardware**: Intel i7-12700H + RTX 3050 Ti Mobile (Optimus)

---

## 📊 PREFLIGHT RESULTS

### Hardware Detected
```
CPU: Intel Core i7-12700H (12th Gen, 20 threads)
GPU: NVIDIA GeForce RTX 3050 Ti Mobile + Intel Iris Xe Graphics
RAM: 20 threads (likely 32GB+)
Target Drive: /dev/nvme1n1 (953.9GB - MTFDKBA1T0TFH-1BC1AABHA)
Current Ubuntu: /dev/nvme0n1 (476.9GB - KINGSTON OM8PDP3512B-AI1)
```

### Disk Layout Plan
```
/dev/nvme1n1 (953.9GB)
├── /dev/nvme1n1p1 (512M) - EFI System Partition
├── /dev/nvme1n1p2 (100GB) - LUKS Encrypted LVM
│   ├── arch-vg-root (100GB) - Encrypted Root
│   ├── arch-vg-swap (8GB) - Encrypted Swap
│   └── arch-vg-home (Remaining) - Encrypted Home
└── /dev/nvme1n1p3 (~845GB) - Warehouse Partition (Unencrypted)
```

---

## 🚀 OPTIMAL CONFIGURATION

### Essential Packages (As Requested)
- ✅ **base-devel** - Development tools
- ✅ **git** - Version control
- ✅ **python** - Python interpreter
- ✅ **docker** - Containerization
- ✅ **vim** - Text editor
- ✅ **networkmanager** - Network management

### Advanced Optimizations (Commonly Forgotten)

#### 🎮 NVIDIA Optimus Configuration
- **nvidia** - Latest NVIDIA drivers
- **nvidia-utils** - NVIDIA utilities
- **nvidia-settings** - NVIDIA control panel
- **nvidia-prime** - Optimus switching
- **prime-run** - GPU offloading support

#### 🖥️ Intel Graphics Support
- **mesa** - OpenGL implementation
- **lib32-mesa** - 32-bit OpenGL support
- **vulkan-intel** - Intel Vulkan driver
- **lib32-vulkan-intel** - 32-bit Vulkan support
- **intel-media-sdk** - Hardware acceleration

#### 🪟 i3 Window Manager Suite
- **i3-wm** - Tiling window manager
- **i3status** - Status bar
- **i3lock** - Screen locker
- **dmenu** - Application launcher
- **rofi** - Advanced launcher
- **feh** - Image viewer/background
- **picom** - Compositor
- **alacritty** - GPU-accelerated terminal

#### 🔧 Development Environment
- **nodejs** - JavaScript runtime
- **npm** - Node package manager
- **rust** - Rust programming language
- **go** - Go programming language
- **podman** - Alternative to Docker

#### 🛡️ Security & System Tools
- **htop** - Process monitor
- **neofetch** - System information
- **tree** - Directory tree viewer
- **wget/curl** - Download tools
- **openssh** - SSH server
- **ufw** - Firewall
- **firewalld** - Advanced firewall

#### 🎵 Media & Network
- **ffmpeg** - Media processing
- **vlc** - Media player
- **mpv** - Lightweight media player
- **wireshark-cli** - Network analysis
- **nmap** - Network scanner
- **netcat-openbsd** - Network utility

---

## 🔐 SECURITY FEATURES

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

## 🎯 INSTALLATION COMMANDS

### Option 1: Direct Installation (Recommended)
```bash
# Boot from Arch live USB
# Download and run the advanced installer
wget https://raw.githubusercontent.com/yourusername/arch-auto-installer/main/install-advanced.sh
chmod +x install-advanced.sh
./install-advanced.sh michael-arch-config.conf
```

### Option 2: Custom ISO
```bash
# Create custom ISO with installer baked in
sudo ./remaster-iso.sh
# Write to USB and boot
sudo ./create-usb.sh -i archlinux-autoinstall-YYYYMMDD.iso -d /dev/sdX
```

---

## 📋 POST-INSTALLATION CHECKLIST

### ✅ System Verification
- [ ] Boot into Arch Linux
- [ ] Enter LUKS password
- [ ] Login with user credentials
- [ ] Verify network connectivity
- [ ] Check NVIDIA drivers: `nvidia-smi`
- [ ] Test Optimus: `prime-run glxinfo | grep NVIDIA`

### ✅ i3 Configuration
- [ ] Start i3: `startx`
- [ ] Configure i3: `i3-config-wizard`
- [ ] Test window management
- [ ] Configure status bar

### ✅ Development Setup
- [ ] Verify Docker: `docker --version`
- [ ] Test AUR helper: `paru -S neofetch`
- [ ] Install Cursor IDE: `paru -S cursor-bin`
- [ ] Configure Git: `git config --global user.name "Michael"`

### ✅ Warehouse Access
- [ ] Mount warehouse: `sudo mount /dev/nvme1n1p3 /mnt/warehouse`
- [ ] Test access from Ubuntu
- [ ] Set up shared data structure

---

## 🚨 CRITICAL NOTES

### ⚠️ Destructive Operation
- **WILL WIPE** `/dev/nvme1n1` completely
- **BACKUP** any important data first
- **VERIFY** target disk before proceeding

### 🔧 Hardware Optimizations
- **CPU Governor**: Performance mode for i7-12700H
- **I/O Scheduler**: mq-deadline for NVMe
- **Memory**: Optimized swappiness for 20-thread CPU
- **Graphics**: Optimus configuration for hybrid graphics

### 🌐 Network Requirements
- **Internet connection** required during installation
- **Arch repositories** must be accessible
- **AUR access** for additional packages

---

## 📊 EXPECTED RESULTS

### Installation Time
- **Base system**: 5-10 minutes
- **Desktop environment**: 10-15 minutes
- **Additional packages**: 15-30 minutes
- **Total**: 30-60 minutes

### System Performance
- **Boot time**: 10-15 seconds (with LUKS)
- **Desktop startup**: 3-5 seconds
- **Application launch**: 1-2 seconds
- **Gaming performance**: Full RTX 3050 Ti utilization

### Storage Layout
- **Encrypted root**: 100GB (system + applications)
- **Encrypted home**: ~845GB (user data)
- **Warehouse**: ~845GB (shared with Ubuntu)
- **EFI**: 512MB (boot files)

---

## 🎉 SUCCESS CRITERIA

✅ **Fully automated installation** - No manual intervention  
✅ **i3 window manager** - Tiling desktop environment  
✅ **paru AUR helper** - Package management  
✅ **LUKS encryption** - 100GB encrypted root  
✅ **Warehouse partition** - Shared with Ubuntu  
✅ **NVIDIA Optimus** - RTX 3050 Ti + Iris Xe  
✅ **Cursor IDE** - Post-installation setup  
✅ **All essentials** - base-devel, git, python, docker, vim, networkmanager  

**Mission Status: READY FOR EXECUTION** 🚀
