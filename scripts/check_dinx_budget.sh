#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
smoke_script="$root/scripts/smoke-iso.sh"
max_rootfs_packages=${DINX_MAX_ROOTFS_PACKAGES:-128}
max_dinit_entries=${DINX_MAX_DINIT_ENTRIES:-24}
max_native_binary_bytes=${DINX_MAX_NATIVE_BINARY_BYTES:-6291456}
max_boot_window_seconds=${DINX_MAX_BOOT_WINDOW_SECONDS:-120}
max_iso_bytes=${DINX_MAX_ISO_BYTES:-4294967296}
boot_window_seconds=${DINX_QEMU_TIMEOUT:-60}

fail() {
  printf 'check_dinx_budget: %s\n' "$*" >&2
  exit 1
}

[[ -r "$profile" ]] || fail "missing profile: $profile"
[[ -r "$smoke_script" ]] || fail "missing smoke script: $smoke_script"
[[ "$boot_window_seconds" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_QEMU_TIMEOUT must be a positive integer'

rootfs_packages=$(awk '
  /^rootfs:/{in_root=1; next}
  /^livefs:/{in_root=0}
  in_root && /^  packages-init:/{in_root=0}
  in_root && /^    - /{count++}
  END{print count + 0}
' "$profile")
dinit_entries=$(awk '
  /^  packages-init:/{in_init=1; next}
  /^livefs:/{in_init=0}
  in_init && /^      - /{count++}
  END{print count + 0}
' "$profile")

(( rootfs_packages <= max_rootfs_packages )) || fail "rootfs package budget exceeded: $rootfs_packages > $max_rootfs_packages"
(( dinit_entries <= max_dinit_entries )) || fail "dinit startup budget exceeded: $dinit_entries > $max_dinit_entries"
(( boot_window_seconds <= max_boot_window_seconds )) || fail "QEMU boot window budget exceeded: $boot_window_seconds > $max_boot_window_seconds"

binary_report=()
for binary in \
  "$root/distro/packages/dinxpanel/zig-out/bin/dinxpanel" \
  "$root/distro/packages/dinitui/zig-out/bin/dinitui"; do
  if [[ -f "$binary" ]]; then
    bytes=$(stat -c '%s' "$binary")
    (( bytes <= max_native_binary_bytes )) || fail "native binary budget exceeded: $binary is $bytes bytes"
    binary_report+=("$(basename "$binary")=$bytes")
  else
    binary_report+=("$(basename "$binary")=not_built")
  fi
done

iso_report=iso=not_measured
if [[ -n "${DINX_ISO_PATH:-}" ]]; then
  [[ -f "$DINX_ISO_PATH" ]] || fail "ISO not found: $DINX_ISO_PATH"
  iso_bytes=$(stat -c '%s' "$DINX_ISO_PATH")
  (( iso_bytes <= max_iso_bytes )) || fail "ISO size budget exceeded: $iso_bytes > $max_iso_bytes"
  iso_report="iso_bytes=$iso_bytes/$max_iso_bytes"
fi

printf 'dinx_budget_contract rootfs_packages=%s/%s dinit_entries=%s/%s boot_window_seconds=%s/%s %s native_binaries=%s\n' \
  "$rootfs_packages" "$max_rootfs_packages" "$dinit_entries" "$max_dinit_entries" \
  "$boot_window_seconds" "$max_boot_window_seconds" "$iso_report" "${binary_report[*]}"
