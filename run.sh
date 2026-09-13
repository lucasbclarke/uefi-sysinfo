#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

zig build
cp zig-out/bin/uefi_zig.efi esp/EFI/BOOT/BOOTX64.EFI

OVMF=$(nix build nixpkgs#OVMF.fd --no-link --print-out-paths)
#qemu-system-x86_64 \
#    -drive if=pflash,format=raw,readonly=on,file="$OVMF/FV/OVMF_CODE.fd" \
#    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
#    -drive format=raw,file=fat:rw:esp \
#    -net none
qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF/FV/OVMF_CODE.fd" \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive format=raw,file=fat:rw:esp \
    -net none \
    -device qxl-vga \
    -display gtk
