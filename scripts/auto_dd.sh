#!/bin/bash
# DD Windows Installation Script
# Simple method using pre-made images

set -e

VERSION="$1"
LOG_FILE="/tmp/dd_install.log"

log() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

# DD images mapping
case $VERSION in
    "win_10")
        DD_URL="https://example.com/win10.gz"
        ;;
    "win_11") 
        DD_URL="https://example.com/win11.gz"
        ;;
    "server_2019")
        DD_URL="https://example.com/win2019.gz"
        ;;
    "server_2022")
        DD_URL="https://example.com/win2022.gz"
        ;;
    *)
        echo "Unknown version: $VERSION"
        exit 1
        ;;
esac

log "Starting DD installation for: $VERSION"

# Download and write image
log "Downloading and writing image..."
wget -O- "$DD_URL" | gunzip | dd of=/dev/vda bs=1M status=progress

if [ $? -eq 0 ]; then
    log "DD installation successful"
    log "Rebooting..."
    reboot
else
    log "DD installation failed"
    exit 1
fi
