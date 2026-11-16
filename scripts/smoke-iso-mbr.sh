#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: Apache-2.0
#
# Legacy BIOS/MBR boot smoke: attach the ISO as a read-only disk and boot it
# through its hybrid MBR with SeaBIOS (no OVMF, no El Torito CD emulation).
# Proves the grub2 MBR loads the ISO menu from a disk device, then selects
# "Start DINX Linux (compatibility)" (noapic irqpoll nomodeset) and requires
# the DINX live desktop marker in the captured session frame. This is the
# HP dm1 / AMD E-350 class boot path; QEMU evidence, not physical hardware.
set -euo pipefail

iso_path=${1:-}
timeout_seconds=${DINX_MBR_TIMEOUT:-150}
memory_mb=${DINX_MBR_MEMORY:-2048}
output_dir=${DINX_MBR_OUTPUT_DIR:-}
menu_delay=${DINX_MBR_MENU_DELAY:-8}
session_delay=${DINX_MBR_SESSION_DELAY:-90}

fail() {
  printf 'smoke-iso-mbr: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso_path" && $# -eq 1 ]] || fail 'usage: scripts/smoke-iso-mbr.sh PATH_TO_ISO'
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
[[ "$iso_path" == /* ]] || iso_path="$PWD/$iso_path"
for command in qemu-system-x86_64 socat tesseract timeout truncate mktemp; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

work_dir=$output_dir
if [[ -z "$work_dir" ]]; then
  work_dir=$(mktemp -d)
else
  mkdir -p "$work_dir" || fail "cannot create output directory: $work_dir"
fi
disk_image="$work_dir/dinx-mbr-boot.img"
monitor_path="$work_dir/qemu.monitor"
menu_frame="$work_dir/mbr-menu.ppm"
session_frame="$work_dir/mbr-session.ppm"

# The ISO image itself becomes the boot disk: SeaBIOS must reach the GRUB
# menu through the hybrid MBR code, exactly like a dd-written USB on a
# BIOS-only notebook.
truncate -s ${DINX_MBR_DISK_BYTES:-8589934592} "$disk_image"
cat "$iso_path" > "$disk_image"

qemu_pid=
cleanup() {
  if [[ -n "$qemu_pid" ]]; then
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
  fi
  rm -f -- "$disk_image"
  [[ -n "$output_dir" ]] || rm -rf -- "$work_dir"
}
trap cleanup EXIT

accel=( -accel tcg,thread=multi )
[[ -r /dev/kvm ]] && accel=( -accel kvm )
timeout --kill-after=10s "${timeout_seconds}s" \
  qemu-system-x86_64 \
  "${accel[@]}" -m "$memory_mb" \
  -drive file="$disk_image",if=ide,format=raw \
  -boot order=c \
  -display none -vga std \
  -monitor "unix:$monitor_path,server=on,wait=off" \
  -serial "file:$work_dir/qemu.log" \
  -net none -no-reboot -no-shutdown &
qemu_pid=$!

monitor_ready=false
for ((attempt = 0; attempt < 30; attempt++)); do
  if [[ -S "$monitor_path" ]]; then
    monitor_ready=true
    break
  fi
  sleep 1
done
[[ "$monitor_ready" == true ]] || fail 'QEMU monitor socket did not appear'

monitor_send() {
  printf '%s\n' "$1" | socat - "UNIX-CONNECT:$monitor_path" >/dev/null 2>&1 \
    || fail "QEMU monitor rejected: $1"
}

# Poll for the rendered GRUB menu (gfxterm can lag the BIOS handoff), pause
# the six-second countdown, and select the second entry: compatibility.
menu_ready=false
menu_deadline=$((SECONDS + 40))
while (( SECONDS < menu_deadline )); do
  sleep 2
  monitor_send "screendump $menu_frame"
  [[ -s "$menu_frame" ]] || continue
  menu_text=$(tesseract "$menu_frame" - --psm 6 2>/dev/null || true)
  grep -qi 'Start DINX' <<<"$menu_text" && { menu_ready=true; break; }
done
[[ "$menu_ready" == true ]] \
  || fail 'hybrid MBR boot did not display the DINX GRUB menu'
printf 'smoke-iso-mbr: hybrid MBR reached the DINX GRUB menu\n'
monitor_send 'sendkey down'
sleep 1
monitor_send 'sendkey ret'

# Wait for the live session surface, polling the captured frame via OCR.
ready=false
deadline=$((SECONDS + session_delay))
while (( SECONDS < deadline )); do
  sleep 10
  monitor_send "screendump $session_frame"
  [[ -s "$session_frame" ]] || continue
  session_text=$(tesseract "$session_frame" - 2>/dev/null || true)
  if grep -qiE 'Dock|dinx' <<<"$session_text"; then
    ready=true
    break
  fi
done
[[ "$ready" == true ]] \
  || fail 'compatibility boot did not reach the DINX desktop within the window'
printf 'smoke-iso-mbr: compatibility entry booted to the DINX desktop marker\n'
