#!/bin/bash
# Auto Windows Install Script
# Usage: bash install_windows.sh <windows_version>

set -e

# Config
VERSION="$1"
LOG_FILE="/tmp/windows_install.log"
TMP_DIR="/tmp/windows_install"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
    fi
    log "Root check passed"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    if [ -x "$(command -v apt-get)" ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y \
            wget curl grub2 grub-pc grub-efi \
            dosfstools ntfs-3g parted \
            gzip unzip p7zip-full \
            sudo screen qemu-utils || true
            
    elif [ -x "$(command -v yum)" ]; then
        # CentOS/RHEL
        yum update -y
        yum install -y \
            wget curl grub2 grub2-efi grub2-pc \
            dosfstools ntfs-3g parted \
            gzip unzip p7zip \
            sudo screen qemu-img || true
            
    elif [ -x "$(command -v dnf)" ]; then
        # Fedora
        dnf update -y
        dnf install -y \
            wget curl grub2 grub2-efi grub2-pc \
            dosfstools ntfs-3g parted \
            gzip unzip p7zip \
            sudo screen qemu-img || true
    else
        warning "Cannot install dependencies automatically"
    fi
    
    log "Dependencies installed"
}

# Get Windows ISO URL
get_iso_url() {
    case $VERSION in
        "server_2019")
            echo "https://archive.org/download/windows-server-2019_202307/Windows%20Server%202019.iso"
            ;;
        "server_2022")
            echo "https://archive.org/download/windows-11-server-2022_202310/Windows%20Server%202022.iso"
            ;;
        "win_10")
            echo "https://archive.org/download/windows-10-pro-22h2_202312/Win10_22H2_EnglishInternational_x64.iso"
            ;;
        "win_11")
            echo "https://archive.org/download/windows-11-pro-23h2_202401/Win11_23H2_EnglishInternational_x64.iso"
            ;;
        *)
            error "Unknown Windows version: $VERSION"
            ;;
    esac
}

# Download ISO
download_iso() {
    local iso_url=$(get_iso_url)
    local iso_file="$TMP_DIR/windows.iso"
    
    log "Downloading Windows ISO from: $iso_url"
    
    # Create temp directory
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"
    
    # Download with resume support
    if command -v wget &> /dev/null; then
        wget -c -O "$iso_file" "$iso_url" || {
            error "Failed to download ISO with wget"
        }
    elif command -v curl &> /dev/null; then
        curl -L -C - -o "$iso_file" "$iso_url" || {
            error "Failed to download ISO with curl"
        }
    else
        error "Neither wget nor curl available"
    fi
    
    # Check if download successful
    if [ ! -f "$iso_file" ] || [ ! -s "$iso_file" ]; then
        error "Downloaded file is empty or missing"
    fi
    
    log "ISO downloaded successfully: $(du -h "$iso_file" | cut -f1)"
}

# Create disk image
create_disk_image() {
    log "Creating disk image..."
    
    # Size based on version
    case $VERSION in
        "server_2019"|"server_2022")
            IMG_SIZE="15G"
            ;;
        "win_10"|"win_11")
            IMG_SIZE="12G"
            ;;
        *)
            IMG_SIZE="10G"
            ;;
    esac
    
    # Create image file
    dd if=/dev/zero of="$TMP_DIR/win.img" bs=1M count=1 seek=$(( ${IMG_SIZE%G} * 1024 - 1 )) status=progress
    
    if [ $? -ne 0 ]; then
        error "Failed to create disk image"
    fi
    
    log "Disk image created: $IMG_SIZE"
}

# Partition and format
setup_disk() {
    log "Setting up disk partitions..."
    
    local img_file="$TMP_DIR/win.img"
    
    # Create partition table
    parted -s "$img_file" mklabel msdos
    parted -s "$img_file" mkpart primary ntfs 1MiB 100%
    parted -s "$img_file" set 1 boot on
    
    # Format partition
    losetup -fP "$img_file"
    local loop_dev=$(losetup -l | grep "$img_file" | awk '{print $1}')
    
    if [ -z "$loop_dev" ]; then
        error "Failed to setup loop device"
    fi
    
    # Format as NTFS
    mkfs.ntfs -f "${loop_dev}p1"
    
    # Cleanup loop
    losetup -d "$loop_dev"
    
    log "Disk setup completed"
}

# Install bootloader
install_bootloader() {
    log "Installing bootloader..."
    
    local img_file="$TMP_DIR/win.img"
    
    # Mount the image
    losetup -fP "$img_file"
    local loop_dev=$(losetup -l | grep "$img_file" | awk '{print $1}')
    
    # Mount partitions
    local mount_point="/mnt/windows_install"
    mkdir -p "$mount_point"
    mount "${loop_dev}p1" "$mount_point"
    
    # Extract boot files from ISO
    local iso_file="$TMP_DIR/windows.iso"
    
    # Create boot directory
    mkdir -p "$mount_point/boot"
    
    # Extract bootmgr and BCD
    7z x "$iso_file" -o"$mount_point" bootmgr bootmgr.efi boot/ boot/efi/ boot/bcd -r > /dev/null 2>&1 || true
    
    # Install GRUB as fallback
    grub-install --target=i386-pc --boot-directory="$mount_point/boot" --modules="ntfs part_msdos" "$img_file" || true
    
    # Create GRUB config
    cat > "$mount_point/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "Windows Setup" {
    insmod ntfs
    insmod part_msdos
    set root='(hd0,msdos1)'
    ntldr /bootmgr
    boot
}

menuentry "Windows Boot Manager" {
    insmod ntfs
    insmod part_msdos
    set root='(hd0,msdos1)'
    chainloader /bootmgr.efi
    boot
}
EOF
    
    # Unmount
    umount "$mount_point"
    losetup -d "$loop_dev"
    
    log "Bootloader installed"
}

# Write to system disk
write_to_disk() {
    log "Writing Windows image to system disk..."
    
    local img_file="$TMP_DIR/win.img"
    local sys_disk="/dev/vda"
    
    # Detect system disk
    if [ ! -b "/dev/vda" ]; then
        if [ -b "/dev/sda" ]; then
            sys_disk="/dev/sda"
        else
            error "Cannot detect system disk"
        fi
    fi
    
    log "Target disk: $sys_disk"
    
    # Warning message
    warning "THIS WILL ERASE ALL DATA ON $sys_disk"
    warning "Continuing in 5 seconds..."
    sleep 5
    
    # Write image to disk
    log "Writing image to disk (this may take a while)..."
    dd if="$img_file" of="$sys_disk" bs=1M status=progress
    
    if [ $? -ne 0 ]; then
        error "Failed to write image to disk"
    fi
    
    # Sync and flush
    sync
    
    log "Windows image successfully written to disk"
}

# Cleanup
cleanup() {
    log "Cleaning up temporary files..."
    
    # Remove temp directory
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
    
    # Remove log file if small
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -lt 1000000 ]; then
        rm -f "$LOG_FILE"
    fi
    
    log "Cleanup completed"
}

# Main installation function
main() {
    log "=== Starting Windows Installation ==="
    log "Version: $VERSION"
    
    # Check requirements
    check_root
    install_dependencies
    
    # Installation steps
    download_iso
    create_disk_image
    setup_disk
    install_bootloader
    write_to_disk
    
    log "=== Windows Installation Completed ==="
    log "System will reboot in 10 seconds..."
    
    # Final cleanup
    cleanup
    
    # Reboot
    sleep 10
    reboot
}

# Error handler
trap 'error "Installation failed at line $LINENO"' ERR

# Run main function
main "$@"
