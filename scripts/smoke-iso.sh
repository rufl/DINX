#!/usr/bin/env bash
set -euo pipefail

iso_path=${1:-}
timeout_seconds=${DINX_QEMU_TIMEOUT:-60}
memory_mb=${DINX_QEMU_MEMORY:-2048}
log_path=${DINX_QEMU_LOG:-}

fail() {
  printf 'smoke-iso: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso_path" ]] || fail "usage: scripts/smoke-iso.sh PATH_TO_ISO"
[[ -f "$iso_path" ]] || fail "ISO does not exist: $iso_path"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail "DINX_QEMU_TIMEOUT must be a positive integer"
[[ "$memory_mb" =~ ^[1-9][0-9]*$ ]] || fail "DINX_QEMU_MEMORY must be a positive integer"
command -v qemu-system-x86_64 >/dev/null 2>&1 || fail "required command not found: qemu-system-x86_64"
command -v timeout >/dev/null 2>&1 || fail "required command not found: timeout"

if [[ -z "$log_path" ]]; then
  log_path="${iso_path}.qemu.log"
fi

if [[ -r /dev/kvm ]]; then
  accel=( -accel kvm )
  printf '%s\n' 'smoke-iso: using KVM acceleration'
else
  accel=( -accel tcg,thread=multi )
  printf '%s\n' 'smoke-iso: using TCG acceleration'
fi

set +e
timeout --kill-after=10s "${timeout_seconds}s" \
  qemu-system-x86_64 \
  "${accel[@]}" \
  -m "$memory_mb" \
  -cdrom "$iso_path" \
  -boot order=d \
  -display none \
  -monitor none \
  -serial "file:$log_path" \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -no-reboot \
  -no-shutdown
status=$?
set -e

if [[ "$status" -ne 124 ]]; then
  printf 'smoke-iso: QEMU exited before the %ss boot window (status %s)\n' "$timeout_seconds" "$status" >&2
  if [[ -f "$log_path" ]]; then
    cat "$log_path" >&2
  fi
  exit 1
fi

printf 'smoke-iso: QEMU remained alive for %ss; ISO boot path accepted\n' "$timeout_seconds"
printf 'smoke-iso: serial log: %s\n' "$log_path"
