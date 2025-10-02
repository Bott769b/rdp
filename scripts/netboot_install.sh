#!/bin/bash
# Netboot Windows Installation
# Alternative method using netboot.xyz

set -e

VERSION="$1"
LOG_FILE="/tmp/netboot_install.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date)]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

log "Starting Netboot installation for: $VERSION"

# Install grub and dependencies
if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y grub2-common grub-pc-bin wget
elif command -v yum &> /dev/null; then
    yum install -y grub2 wget
fi

# Download netboot.xyz
log "Downloading netboot.xyz..."
wget -O /tmp/netboot.xyz.iso https://boot.netboot.xyz/ipxe/netboot.xyz.iso

# Create custom grub config
log "Configuring GRUB..."
cat > /etc/grub.d/40_custom << 'EOF'
#!/bin/sh
exec tail -n +3 $0

menuentry "Netboot.xyz - Windows Install" {
    set root='(hd0,1)'
    linux16 /netboot.xyz.lkrn
}
EOF

# Update grub
update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub2/grub.cfg

log "Netboot setup completed"
log "System will reboot to netboot in 5 seconds..."

sleep 5
reboot
