#!/bin/bash

# Setup script to push Arch Linux installer to GitHub repository

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
REPO_URL="https://github.com/Phantomojo/archlinux.git"
LOCAL_DIR="/home/phantomojo/HTB/arch-auto-installer"

main() {
    log "Setting up Arch Linux installer repository..."
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install git first."
    fi
    
    # Navigate to the installer directory
    cd "$LOCAL_DIR"
    
    # Initialize git repository if not already initialized
    if [[ ! -d ".git" ]]; then
        log "Initializing git repository..."
        git init
    fi
    
    # Add remote origin
    log "Adding remote repository..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "$REPO_URL"
    
    # Add all files
    log "Adding files to repository..."
    git add .
    
    # Create initial commit
    log "Creating initial commit..."
    git commit -m "Initial commit: Arch Linux Automated Installer

- Fully automated Arch Linux installer with LUKS encryption
- Optimized for Intel i7-12700H + RTX 3050 Ti Mobile
- i3 window manager + paru AUR helper
- Warehouse partition for Ubuntu compatibility
- Comprehensive documentation and testing tools"
    
    # Push to GitHub
    log "Pushing to GitHub repository..."
    git branch -M main
    git push -u origin main
    
    success "Repository setup completed successfully!"
    echo
    echo -e "${GREEN}Your Arch Linux installer is now available at:${NC}"
    echo "https://github.com/Phantomojo/archlinux"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Boot from Arch Linux live USB"
    echo "2. Run: wget https://raw.githubusercontent.com/Phantomojo/archlinux/main/install-advanced.sh"
    echo "3. Run: wget https://raw.githubusercontent.com/Phantomojo/archlinux/main/michael-arch-config.conf"
    echo "4. Run: chmod +x install-advanced.sh && ./install-advanced.sh michael-arch-config.conf"
    echo
    echo -e "${BLUE}Files available:${NC}"
    echo "- install-advanced.sh (main installer)"
    echo "- michael-arch-config.conf (your configuration)"
    echo "- README.md (comprehensive documentation)"
    echo "- test-installer-validation.sh (testing script)"
}

# Run main function
main "$@"
