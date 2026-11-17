#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: Apache-2.0
#
# Legacy BIOS/MBR boot smoke: attach the ISO as a read-only disk and boot it
# through its hybrid MBR with SeaBIOS (no OVMF, no El Torito CD emulation).
# Proves the grub2 MBR loads the ISO menu from a disk device, then selects
# "Start DINX Linux (compatibility)" (noapic irqpoll, the legacy interrupt
# route workaround) and requires the graphical DINX session through the
# shared session checker, which rejects getty/login surfaces. This is the
# HP dm1 / AMD E-350 class boot path; QEMU evidence, not physical hardware.
set -euo pipefail

iso_path=${1:-}
timeout_seconds=${DINX_MBR_TIMEOUT:-420}
memory_mb=${DINX_MBR_MEMORY:-2048}
output_dir=${DINX_MBR_OUTPUT_DIR:-}
ocr_language=${DINX_MBR_OCR_LANG:-eng}

fail() {
  printf 'smoke-iso-mbr: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso_path" && $# -eq 1 ]] || fail 'usage: scripts/smoke-iso-mbr.sh PATH_TO_ISO'
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
[[ "$iso_path" == /* ]] || iso_path="$PWD/$iso_path"
for command in qemu-system-x86_64 socat tesseract timeout truncate mktemp python3; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

# The CI runners boot this path under TCG: the menu needs the BIOS handoff,
# GRUB module loading and gfxterm before any key can be sent.
menu_wait=${DINX_MBR_MENU_WAIT:-180}
session_wait=${DINX_MBR_SESSION_WAIT:-180}
(( menu_wait + session_wait + 15 < timeout_seconds )) \
  || fail 'DINX_MBR wait budget must stay below DINX_MBR_TIMEOUT'
ocr_languages=$(tesseract --list-langs 2>&1) \
  || fail 'Tesseract could not list installed language data'
IFS='+' read -r -a requested_ocr_languages <<< "$ocr_language"
for language in "${requested_ocr_languages[@]}"; do
  grep -Fqx "$language" <<< "$ocr_languages" \
    || fail "Tesseract language data '$language' is missing; install tesseract-ocr-eng or set DINX_MBR_OCR_LANG to an installed model"
done

work_dir=$output_dir
if [[ -z "$work_dir" ]]; then
  work_dir=$(mktemp -d)
else
  mkdir -p "$work_dir" || fail "cannot create output directory: $work_dir"
fi
disk_image="$work_dir/dinx-mbr-boot.img"
monitor_path="$work_dir/qemu.monitor"
menu_frame="$work_dir/dinx-mbr-menu.ppm"
session_frame="$work_dir/dinx-mbr-session.ppm"

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

# The ISO image itself becomes the boot disk: SeaBIOS must reach the GRUB
# menu through the hybrid MBR code, exactly like a dd-written USB on a
# BIOS-only notebook.
truncate -s ${DINX_MBR_DISK_BYTES:-8589934592} "$disk_image"
cat "$iso_path" > "$disk_image"

accel=( -accel tcg,thread=multi )
[[ -r /dev/kvm ]] && accel=( -accel kvm )
printf 'smoke-iso-mbr: booting %s from its hybrid MBR (%s)\n' "${iso_path##*/}" "${accel[1]}"

timeout --kill-after=10s "${timeout_seconds}s" \
  qemu-system-x86_64 \
  "${accel[@]}" -m "$memory_mb" \
  -drive file="$disk_image",if=ide,format=raw \
  -boot order=c \
  -display none -vga std \
  -monitor "unix:$monitor_path,server=on,wait=off" \
  -serial "file:$work_dir/dinx-mbr.qemu.log" \
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

# Boot-menu frames are low-resolution gfxterm captures: auto page
# segmentation returns empty text, so nearest-neighbour enlarge and force a
# fixed-layout mode like the CI graphical smoke does.
ocr_frame() {
  local frame="$1"
  local enlarged="$frame.upscaled.ppm"
  local text=
  if python3 - "$frame" <<'PY' > "$enlarged" 2>/dev/null
import sys
with open(sys.argv[1], 'rb') as handle:
    data = handle.read()
parts = data.split(b'\n', 3)
if len(parts) != 4 or parts[0] != b'P6':
    sys.exit(1)
width, height = (int(value) for value in parts[1].split())
scale = 3
body = parts[3]
out = [parts[0], f"{width * scale} {height}".encode(), parts[2]]
rows = []
for y in range(height):
    row = body[y * width * 3:(y + 1) * width * 3]
    enlarged = bytearray()
    for x in range(width):
        enlarged += row[x * 3:x * 3 + 3] * scale
    rows += [bytes(enlarged)] * scale
sys.stdout.buffer.write(b'\n'.join(out) + b'\n' + b''.join(rows))
PY
  then
    text=$(tesseract "$enlarged" - -l "$ocr_language" --psm 11 2>/dev/null || true)
  fi
  rm -f -- "$enlarged"
  if [[ -z "${text//[[:space:]]/}" ]]; then
    text=$(tesseract "$frame" - -l "$ocr_language" --psm 6 2>/dev/null || true)
  fi
  printf '%s' "$text"
}

menu_ready=false
menu_text=
menu_deadline=$((SECONDS + menu_wait))
while (( SECONDS < menu_deadline )); do
  sleep 3
  monitor_send "screendump $menu_frame"
  [[ -s "$menu_frame" ]] || continue
  menu_text=$(ocr_frame "$menu_frame")
  if grep -qi 'DINX' <<<"$menu_text"; then
    menu_ready=true
    break
  fi
done
[[ "$menu_ready" == true ]] \
  || fail "hybrid MBR boot did not display the DINX GRUB menu (ocr: ${menu_text:0:120})"
printf 'smoke-iso-mbr: hybrid MBR reached the DINX GRUB menu\n'

# Any keypress pauses the countdown; select the second menu entry
# (compatibility kernel parameters) before the default boots.
monitor_send 'sendkey down'
sleep 1
monitor_send 'sendkey ret'

<<<<<<< HEAD
# The compatibility session must reach the graphical shell: the River/KWM +
# Morghulis desktop, whose compositor window is titled "River + KWM +
# Morghulis (DINX)" and whose shell surfaces (Morghulis NavBar, dinx-dock) or
# the DINX first-run wizard identify it. This mirrors the marker vocabulary in
# check_dinx_qemu_session.sh. A getty frame (`dinxlive login:`, `tty1`) proves
# the session failed to start and must not pass, so require a positive marker
# and reject the text login.
=======
# The compatibility session must reach the graphical shell: the Pearl
# first-run `Dock` window or the Aqueous/Pearl surface. A getty frame
# (`dinxlive login:`, `tty1`) proves the session failed to start and must
# not pass, so require a positive marker and reject the text login.
>>>>>>> 4586d38 (feat(iso): add legacy BIOS/MBR (compatibility) boot support)
ready=false
session_text=
session_deadline=$((SECONDS + session_wait))
while (( SECONDS < session_deadline )); do
  sleep 10
  monitor_send "screendump $session_frame"
  [[ -s "$session_frame" ]] || continue
  session_text=$(ocr_frame "$session_frame")
<<<<<<< HEAD
  if grep -Eiq '(^|[^[:alnum:]_])(River|KWM|Morghulis|DINX)([^[:alnum:]_]|$)' <<<"$session_text" \
=======
  if grep -Eiq '(^|[^[:alnum:]_])(Dock|Pearl|Aqueous)([^[:alnum:]_]|$)' <<<"$session_text" \
>>>>>>> 4586d38 (feat(iso): add legacy BIOS/MBR (compatibility) boot support)
    && ! grep -Eiq 'login[[:space:]]*:|tty[[:space:]]*[0-9]|password' <<<"$session_text"; then
    ready=true
    break
  fi
done
[[ "$ready" == true ]] \
  || fail "compatibility boot did not reach the DINX graphical session (ocr: ${session_text:0:160})"
printf 'smoke-iso-mbr: compatibility entry booted to the DINX desktop marker\n'
