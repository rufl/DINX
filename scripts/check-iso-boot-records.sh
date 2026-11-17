#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: Apache-2.0
#
# Static boot-record gate for a DINX ISO: the image must stay hybrid-bootable
# on legacy BIOS/MBR machines (AMD E-350 "Zacate" laptops and similar) as well
# as UEFI. Checks the MBR signature and hybrid partition table, the grub2-mbr
# system area, and both El Torito entries (i386-pc cdboot and the EFI image).
set -euo pipefail

iso_path=${1:-}

fail() {
  printf 'check-iso-boot-records: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso_path" && $# -eq 1 ]] || fail 'usage: scripts/check-iso-boot-records.sh PATH_TO_ISO'
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
for command in xorriso python3 grep; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

# 1. MBR layout: boot signature, active ISO partition, appended ESP inside the file.
python3 - "$iso_path" <<'PY' || fail 'MBR is not a valid bootable hybrid partition table'
import os
import struct
import sys

iso = sys.argv[1]
size = os.path.getsize(iso)
with open(iso, 'rb') as handle:
    sector0 = handle.read(512)
if len(sector0) < 512:
    sys.exit('image shorter than one MBR sector')
if sector0[510:512] != b'\x55\xaa':
    sys.exit(f'missing MBR boot signature: {sector0[510:512].hex()}')
entries = [sector0[446 + 16 * i:462 + 16 * i] for i in range(4)]
bootable = [e for e in entries if e[0] == 0x80]
if len(bootable) != 1:
    sys.exit('MBR does not mark exactly one partition bootable (0x80)')
iso_entry = bootable[0]
iso_lba, iso_sectors = struct.unpack('<II', iso_entry[8:16])
if iso_lba == 0 or iso_lba + iso_sectors > size // 512:
    sys.exit(f'MBR ISO partition exceeds the image: lba={iso_lba} sectors={iso_sectors} file={size}')
esp = [e for e in entries if e[4] == 0xef]
if len(esp) != 1:
    sys.exit('MBR does not carry exactly one EFI System partition entry (0xef)')
esp_lba, esp_sectors = struct.unpack('<II', esp[0][8:16])
if esp_lba == 0 or esp_lba + esp_sectors > size // 512:
    sys.exit(f'MBR ESP partition exceeds the image: lba={esp_lba} sectors={esp_sectors} file={size}')
if esp_lba < iso_lba + iso_sectors:
    sys.exit('MBR ESP partition overlaps the ISO partition')
PY

# 2. xorriso system area: grub2 hybrid MBR with the ISO9660 partition offset.
system_area=$(xorriso -indev "$iso_path" -report_system_area plain 2>/dev/null) \
  || fail 'xorriso could not read the ISO system area'
grep -Fq 'MBR grub2-mbr' <<<"$system_area" \
  || fail 'ISO system area does not carry the grub2 hybrid MBR'
grep -Eq '^Partition offset   : 16$' <<<"$system_area" \
  || fail 'ISO hybrid MBR does not use partition offset 16'

# 3. El Torito: BIOS cdboot entry with grub2 boot info plus the EFI fallback entry.
el_torito=$(xorriso -indev "$iso_path" -report_el_torito as_mkisofs 2>/dev/null) \
  || fail 'xorriso could not read the ISO El Torito boot records'
grep -Fq -- '--grub2-mbr' <<<"$el_torito" \
  || fail 'ISO El Torito report does not replay a grub2 MBR'
grep -Fq 'i386-pc/eltorito.img' <<<"$el_torito" \
  || fail 'ISO lacks the legacy BIOS El Torito boot image'
grep -Fq -- '--grub2-boot-info' <<<"$el_torito" \
  || fail 'ISO legacy BIOS boot image lacks the grub2 boot-info patch point'
grep -Fq -- '-eltorito-alt-boot' <<<"$el_torito" \
  || fail 'ISO lacks the alternative (EFI) El Torito boot entry'
grep -Fq -- '--mbr-force-bootable' <<<"$el_torito" \
  || fail 'ISO hybrid MBR partition is not forced bootable'
grep -Fq -- '-append_partition 2 0xef' <<<"$el_torito" \
  || fail 'ISO does not append its EFI System partition to the hybrid MBR'

# 4. The BIOS boot image and ESP payload must exist inside the ISO tree.
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
xorriso -osirrox on -indev "$iso_path" \
  -extract /boot/grub/i386-pc/eltorito.img "$tmp_dir/eltorito.img" \
  -extract /boot/efi.img "$tmp_dir/efi.img" >/dev/null 2>&1 \
  || fail 'ISO does not contain its BIOS boot image or /boot/efi.img'
[[ -s "$tmp_dir/eltorito.img" ]] || fail 'extracted BIOS boot image is empty'
efi_size=$(stat -c %s "$tmp_dir/efi.img" 2>/dev/null || echo 0)
[[ "$efi_size" -ge 1048576 ]] \
  || fail "ISO /boot/efi.img is implausibly small: $efi_size bytes"

printf 'check-iso-boot-records: hybrid MBR, BIOS El Torito and EFI boot records verified: %s\n' "$iso_path"
