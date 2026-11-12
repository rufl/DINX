#!/usr/bin/env bash
# DINX-BSD Automated QEMU ISO Builder & Bootstrapper
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)

fail() {
  printf 'build-bsd-iso: %s\n' "$*" >&2
  exit 1
}

output_dir="$repo_root/dist/bsd-iso"
mkdir -p "$output_dir"

rm -f "$output_dir/FreeBSD-14.2-RELEASE-amd64-disc1.iso"

command -v qemu-system-x86_64 >/dev/null 2>&1 || fail 'qemu-system-x86_64 not found'

freebsd_img="$output_dir/freebsd-VM.qcow2"
installer_iso="$output_dir/FreeBSD-14.5-RELEASE-amd64-disc1.iso"

if [[ ! -f "$freebsd_img" ]]; then
  printf 'build-bsd-iso: creating 20G virtual disk...\n'
  qemu-img create -f qcow2 "$freebsd_img" 20G
fi

printf 'build-bsd-iso: FreeBSD 14.5 installer ISO ready at %s\n' "$installer_iso"
printf 'build-bsd-iso: to launch QEMU installer VM, run:\n'
printf '  qemu-system-x86_64 -m 4G -smp 4 -enable-kvm -hda %s -cdrom %s -boot d -net nic,model=virtio -net user\n' "$freebsd_img" "$installer_iso"
