#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

iso_path=${1:-}
timeout_seconds=${DINX_QEMU_TIMEOUT:-60}
memory_mb=${DINX_QEMU_MEMORY:-2048}
log_path=${DINX_QEMU_LOG:-}
screenshot_path=${DINX_QEMU_SCREENSHOT:-}
boot_screenshot_path=${DINX_QEMU_BOOT_SCREENSHOT:-}
screenshot_delay=${DINX_QEMU_SCREENSHOT_DELAY:-30}
boot_screenshot_delay=${DINX_QEMU_BOOT_SCREENSHOT_DELAY:-3}
boot_keys=${DINX_QEMU_BOOT_KEYS:-}
post_screenshot_path=${DINX_QEMU_POST_SCREENSHOT:-}
post_screenshot_delay=${DINX_QEMU_POST_SCREENSHOT_DELAY:-10}
post_keys=${DINX_QEMU_POST_KEYS:-}
qemu_display=${DINX_QEMU_DISPLAY:-none}
qemu_video_device=${DINX_QEMU_VIDEO_DEVICE:-}

fail() {
  printf 'smoke-iso: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso_path" ]] || fail "usage: scripts/smoke-iso.sh PATH_TO_ISO"
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail "DINX_QEMU_TIMEOUT must be a positive integer"
[[ "$memory_mb" =~ ^[1-9][0-9]*$ ]] || fail "DINX_QEMU_MEMORY must be a positive integer"
[[ "$screenshot_delay" =~ ^[0-9]+$ ]] || fail "DINX_QEMU_SCREENSHOT_DELAY must be a non-negative integer"
[[ "$post_screenshot_delay" =~ ^[0-9]+$ ]] || fail "DINX_QEMU_POST_SCREENSHOT_DELAY must be a non-negative integer"
[[ "$boot_screenshot_delay" =~ ^[0-9]+$ ]] || fail "DINX_QEMU_BOOT_SCREENSHOT_DELAY must be a non-negative integer"
command -v qemu-system-x86_64 >/dev/null 2>&1 || fail "required command not found: qemu-system-x86_64"
command -v timeout >/dev/null 2>&1 || fail "required command not found: timeout"
command -v socat >/dev/null 2>&1 || fail "required command not found: socat"
command -v tesseract >/dev/null 2>&1 || fail "required command not found: tesseract (install tesseract-ocr and tesseract-ocr-eng)"
(( screenshot_delay < timeout_seconds )) || fail 'DINX_QEMU_SCREENSHOT_DELAY must be shorter than DINX_QEMU_TIMEOUT'

if [[ -z "$log_path" ]]; then
  log_path="${iso_path}.qemu.log"
fi

send_keys() {
  local keys="$1"
  local key
  local input_status=0
  local -a key_list

  IFS=',' read -r -a key_list <<< "$keys"
  for key in "${key_list[@]}"; do
    [[ -n "$key" ]] || fail 'QEMU key list contains an empty key'
    printf 'sendkey %s\n' "$key" \
      | socat - "UNIX-CONNECT:$monitor_path" >/dev/null 2>&1
    input_status=$?
    [[ "$input_status" -eq 0 ]] || return "$input_status"
    sleep 0.5
  done
}

capture_screen() {
  local path="$1"
  printf 'screendump %s\n' "$path" \
    | socat - "UNIX-CONNECT:$monitor_path" >/dev/null 2>&1
}

validate_screenshot() {
  local path="$1"
  local label="$2"
  [[ -s "$path" ]] || fail "QEMU $label screendump is empty: $path"
  local ppm_magic=
  IFS= read -r ppm_magic < "$path" || true
  [[ "$ppm_magic" == P6 ]] || fail "QEMU $label screendump is not a binary PPM: $path"
  local screenshot_size
  screenshot_size=$(wc -c < "$path")
  printf 'smoke-iso: %s screendump: %s (%s bytes)\n' "$label" "$path" "$screenshot_size"
}

if [[ -r /dev/kvm ]]; then
  accel=( -accel kvm )
  printf '%s\n' 'smoke-iso: using KVM acceleration'
else
  accel=( -accel tcg,thread=multi )
  printf '%s\n' 'smoke-iso: using TCG acceleration'
fi
video_args=()
if [[ -n "$qemu_video_device" ]]; then
  video_args=( -vga none -device "$qemu_video_device" )
fi

monitor_dir=$(mktemp -d)
monitor_path="$monitor_dir/qemu.monitor"
monitor_args=( -monitor "unix:$monitor_path,server=on,wait=off" )
session_screenshot_path=${screenshot_path:-"${log_path}.session.ppm"}

if [[ -n "$boot_screenshot_path" ]]; then
  mkdir -p "$(dirname "$boot_screenshot_path")"
fi
if [[ -n "$screenshot_path" ]]; then
  mkdir -p "$(dirname "$screenshot_path")"
fi
if [[ -n "$post_screenshot_path" ]]; then
  mkdir -p "$(dirname "$post_screenshot_path")"
fi
mkdir -p "$(dirname "$session_screenshot_path")"

cleanup() {
  if [[ -n "$monitor_dir" ]]; then
    rm -rf "$monitor_dir"
  fi
}
trap cleanup EXIT

set +e
timeout --kill-after=10s "${timeout_seconds}s" \
  qemu-system-x86_64 \
  "${accel[@]}" \
  -m "$memory_mb" \
  -cdrom "$iso_path" \
  -boot order=d \
  -display "$qemu_display" \
  "${video_args[@]}" \
  "${monitor_args[@]}" \
  -serial "file:$log_path" \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -no-reboot \
  -no-shutdown &
qemu_pid=$!

boot_dump_status=0
dump_status=0
session_dump_status=0
post_dump_status=0
monitor_ready=false
for ((attempt = 0; attempt < 30; attempt++)); do
  if [[ -S "$monitor_path" ]]; then
    monitor_ready=true
    break
  fi
  sleep 1
done

if [[ "$monitor_ready" == true ]]; then
  if [[ -n "$boot_screenshot_path" ]]; then
    sleep "$boot_screenshot_delay"
    capture_screen "$boot_screenshot_path"
    boot_dump_status=$?
  fi

  if [[ -n "$boot_keys" ]]; then
    send_keys "$boot_keys"
    input_status=$?
    [[ "$input_status" -eq 0 ]] || fail 'QEMU monitor rejected boot key input'
    printf 'smoke-iso: sent QEMU boot keys: %s\n' "$boot_keys"
  fi

  if [[ -n "$screenshot_path" ]]; then
    sleep "$screenshot_delay"
    capture_screen "$screenshot_path"
    dump_status=$?
    session_dump_status=$dump_status
  else
    sleep "$screenshot_delay"
    capture_screen "$session_screenshot_path"
    session_dump_status=$?
  fi

  if [[ -n "$post_screenshot_path" ]]; then
    if [[ -n "$post_keys" ]]; then
      send_keys "$post_keys"
      input_status=$?
      [[ "$input_status" -eq 0 ]] || fail 'QEMU monitor rejected post-screenshot key input'
      printf 'smoke-iso: sent post-screenshot QEMU keys: %s\n' "$post_keys"
    fi
    sleep "$post_screenshot_delay"
    capture_screen "$post_screenshot_path"
    post_dump_status=$?
  fi
else
  boot_dump_status=1
  dump_status=1
  session_dump_status=1
  post_dump_status=1
fi

wait "$qemu_pid"
status=$?
set -e

if [[ "$status" -ne 124 ]]; then
  printf 'smoke-iso: QEMU exited before the %ss boot window (status %s)\n' "$timeout_seconds" "$status" >&2
  if [[ -f "$log_path" ]]; then
    cat "$log_path" >&2
  fi
  exit 1
fi


if [[ -n "$boot_screenshot_path" ]]; then
  [[ "$boot_dump_status" -eq 0 ]] || fail 'QEMU monitor did not accept boot screendump'
  validate_screenshot "$boot_screenshot_path" 'boot'
fi
if [[ -n "$screenshot_path" ]]; then
  [[ "$dump_status" -eq 0 ]] || fail 'QEMU monitor did not accept screendump'
  validate_screenshot "$screenshot_path" 'graphical'
else
  [[ "$session_dump_status" -eq 0 ]] || fail 'QEMU monitor did not accept session screendump'
  validate_screenshot "$session_screenshot_path" 'session'
fi
"$script_dir/check_dinx_qemu_session.sh" "$session_screenshot_path"

if [[ -n "$post_screenshot_path" ]]; then
  [[ "$post_dump_status" -eq 0 ]] || fail 'QEMU monitor did not accept post-screenshot screendump'
  validate_screenshot "$post_screenshot_path" 'post'
fi


printf 'smoke-iso: Pearl/Aqueous session reached a graphical-ready screen within %ss\n' "$timeout_seconds"
printf 'smoke-iso: serial log: %s\n' "$log_path"
