#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
mode=full
if [[ ${1:-} == --static ]]; then
  mode=static
  shift
fi
iso_path=${1:-}

fail() {
  printf 'qualify-iso: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso_path" && $# -eq 1 ]] || fail 'usage: scripts/qualify-iso.sh [--static] PATH_TO_ISO'
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
if [[ "$iso_path" != /* ]]; then
  iso_path="$PWD/$iso_path"
fi
iso_dir=$(CDPATH= cd -- "$(dirname -- "$iso_path")" && pwd -P)
iso_name=$(basename -- "$iso_path")
iso_path="$iso_dir/$iso_name"
metadata_path="$iso_dir/build-metadata.txt"

"$script_dir/check-iso-qualification-host.sh" "$mode"
[[ -r "$metadata_path" ]] || fail "build metadata missing: $metadata_path"
DINX_EXPECTED_COMMIT=${DINX_EXPECTED_COMMIT:-${GITHUB_SHA:-}} \
  "$script_dir/check_build_metadata.sh" "$metadata_path" "$iso_path"
checksum_name="$iso_name.sha512"
if [[ ! -f "$iso_dir/$checksum_name" ]]; then
  (cd "$iso_dir" && sha512sum "$iso_name" > "$checksum_name")
fi
(cd "$iso_dir" && sha512sum --check --status "$checksum_name") \
  || fail "ISO SHA-512 checksum does not match: $iso_dir/$checksum_name"
DINX_ISO_PATH="$iso_path" DINX_QEMU_TIMEOUT=${DINX_QEMU_TIMEOUT:-120} \
"$script_dir/check-iso-content.sh" "$iso_path"
# Enforce the payload/startup budgets against the built image. The workflow runs
# this script without DINX_ISO_PATH (no image exists yet), which reports
# iso=not_measured; passing the path here is what actually binds the built ISO to
# the size ceiling.
DINX_ISO_PATH="$iso_path" "$script_dir/check_dinx_budget.sh"
printf 'qualify-iso: static ISO, metadata, checksum, content and budget gates passed: %s\n' "$iso_path"

if [[ "$mode" == static ]]; then
  printf '%s\n' 'qualify-iso: STATIC ONLY; no boot, installation, VirtualBox or physical-hardware evidence was produced'
  exit 0
fi

DINX_QEMU_TIMEOUT=${DINX_QEMU_TIMEOUT:-120} \
DINX_QEMU_BOOT_KEYS=ret \
DINX_QEMU_VIDEO_DEVICE= \
DINX_QEMU_LOG="$iso_dir/dinx-vga.qemu.log" \
DINX_QEMU_BOOT_SCREENSHOT="$iso_dir/dinx-boot-screen.ppm" \
DINX_QEMU_BOOT_SCREENSHOT_DELAY=3 \
DINX_QEMU_PLYMOUTH_SCREENSHOT="$iso_dir/dinx-plymouth-screen.ppm" \
DINX_QEMU_PLYMOUTH_WAIT_SECONDS=30 \
DINX_QEMU_SCREENSHOT="$iso_dir/dinx-graphical-screen.ppm" \
DINX_QEMU_SCREENSHOT_DELAY=57 \
DINX_QEMU_POST_SCREENSHOT="$iso_dir/dinx-session-screen.ppm" \
DINX_QEMU_POST_SCREENSHOT_DELAY=10 \
DINX_QEMU_POST_KEYS=alt-f4 \
  "$script_dir/smoke-iso.sh" "$iso_path"

DINX_QEMU_TIMEOUT=${DINX_QEMU_TIMEOUT:-120} \
DINX_QEMU_BOOT_KEYS=ret \
DINX_QEMU_VIDEO_DEVICE=virtio-vga \
DINX_QEMU_LOG="$iso_dir/dinx-virtio-vga.qemu.log" \
DINX_QEMU_BOOT_SCREENSHOT="$iso_dir/dinx-virtio-vga-boot-screen.ppm" \
DINX_QEMU_BOOT_SCREENSHOT_DELAY=3 \
DINX_QEMU_PLYMOUTH_SCREENSHOT="$iso_dir/dinx-virtio-vga-plymouth-screen.ppm" \
DINX_QEMU_PLYMOUTH_WAIT_SECONDS=30 \
DINX_QEMU_SCREENSHOT="$iso_dir/dinx-virtio-vga-session.ppm" \
DINX_QEMU_SCREENSHOT_DELAY=57 \
DINX_QEMU_POST_SCREENSHOT="$iso_dir/dinx-virtio-vga-session-after-setup.ppm" \
DINX_QEMU_POST_SCREENSHOT_DELAY=10 \
DINX_QEMU_POST_KEYS=alt-f4 \
  "$script_dir/smoke-iso.sh" "$iso_path"

DINX_INSTALL_OUTPUT_DIR="$iso_dir" \
DINX_INSTALL_TIMEOUT=${DINX_INSTALL_TIMEOUT:-180} \
DINX_INSTALL_FIRMWARE=bios \
  "$script_dir/smoke-install.sh" "$iso_path"
DINX_INSTALL_OUTPUT_DIR="$iso_dir" \
DINX_INSTALL_TIMEOUT=${DINX_INSTALL_TIMEOUT:-180} \
DINX_INSTALL_FIRMWARE=uefi \
  "$script_dir/smoke-install.sh" "$iso_path"
printf 'qualify-iso: full QEMU VGA, Virtio-VGA, BIOS and UEFI installation gates passed: %s\n' "$iso_path"
