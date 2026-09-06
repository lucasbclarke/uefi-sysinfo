#!/usr/bin/env bash
# Copy the built EFI application to a USB drive's EFI System Partition.
#
# Usage:
#   ./deploy-usb.sh /dev/sdX        # device with an existing FAT ESP partition
#   ./deploy-usb.sh /dev/sdX1       # partition directly
#   ./deploy-usb.sh /run/media/user/USB   # already-mounted mountpoint
#
# The target must already be formatted FAT12/16/32 (UEFI can only boot that
# from removable media). This script never formats anything.
set -euo pipefail
cd "$(dirname "$0")"

EFI_NAME=BOOTX64.EFI

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <device|partition|mountpoint>" >&2
    echo "example: $0 /dev/sdb1" >&2
    exit 1
fi

TARGET=$1

# Build first so we deploy the current source.
zig build

APP=zig-out/bin/uefi_zig.efi
[[ -f $APP ]] || { echo "error: $APP not found" >&2; exit 1; }

MOUNTED_HERE=0

is_mounted() {
    findmnt -rn -S "$1" -o TARGET 2>/dev/null || true
}

if [[ -b $TARGET ]]; then
    # Block device: resolve partition (whole disk -> first partition).
    PART=$TARGET
    if [[ ! -b ${TARGET}1 && $TARGET == *[0-9] ]]; then
        : # already a partition
    elif lsblk -no TYPE "$TARGET" | grep -q part; then
        :
    else
        PART=$(lsblk -rno NAME,TYPE "$TARGET" | awk '$2=="part"{print "/dev/"$1; exit}')
        [[ -n $PART ]] || { echo "error: no partition found on $TARGET" >&2; exit 1; }
    fi

    # Refuse to touch anything that isn't FAT.
    FSTYPE=$(lsblk -rno FSTYPE "$PART")
    [[ $FSTYPE == vfat || $FSTYPE == msdos ]] || {
        echo "error: $PART is '$FSTYPE', not FAT. UEFI needs a FAT ESP." >&2
        exit 1
    }

    MNT=$(is_mounted "$PART")
    if [[ -z $MNT ]]; then
        MNT=$(mktemp -d)
        udisksctl mount -b "$PART" >/dev/null || sudo mount "$PART" "$MNT"
        MOUNTED_HERE=1
    fi
else
    # Assume a mountpoint.
    MNT=$(findmnt -rn -T "$TARGET" -o TARGET 2>/dev/null || true)
    [[ -n $MNT ]] || { echo "error: $TARGET is not mounted" >&2; exit 1; }
    FSTYPE=$(findmnt -rn -T "$MNT" -o FSTYPE)
    [[ $FSTYPE == vfat || $FSTYPE == msdos ]] || {
        echo "error: $MNT is '$FSTYPE', not FAT. UEFI needs a FAT ESP." >&2
        exit 1
    }
fi

echo "Deploying to $MNT"
mkdir -p "$MNT/EFI/BOOT"
cp "$APP" "$MNT/EFI/BOOT/$EFI_NAME"
sync

if (( MOUNTED_HERE )); then
    udisksctl unmount -b "${PART}" >/dev/null 2>&1 || sudo umount "$MNT"
    rmdir "$MNT"
fi

echo "Done. Boot the machine with USB selected in the firmware boot menu."
