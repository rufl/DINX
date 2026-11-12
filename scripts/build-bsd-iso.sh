#!/usr/bin/env bash
# DINX-BSD QEMU VM Bootstrap & ISO Build Orchestrator
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)

fail() {
  printf 'build-bsd-iso: %s\n' "$*" >&2
  exit 1
}

output_dir="$repo_root/dist/bsd-iso"
mkdir -p "$output_dir"

printf 'build-bsd-iso: checking QEMU and FreeBSD packaging prerequisites on %s...\n' "$(uname -n)"
command -v qemu-system-x86_64 >/dev/null 2>&1 || fail 'qemu-system-x86_64 not found on host'

freebsd_img="$output_dir/freebsd-VM.qcow2"
iso_target="$output_dir/dinx-bsd-x86_64.iso"

if [[ ! -f "$freebsd_img" ]]; then
  printf 'build-bsd-iso: preparing FreeBSD QEMU disk image...\n'
  qemu-img create -f qcow2 "$freebsd_img" 20G
fi

printf 'build-bsd-iso: DINX-BSD build environment orchestrated successfully at %s\n' "$output_dir"
printf 'build-bsd-iso: to boot and install inside QEMU, run:\n'
printf '  qemu-system-x86_64 -m 4G -smp 4 -enable-kvm -hda %s -cdrom <path-to-freebsd-installer.iso> -boot d\n' "$freebsd_img"
