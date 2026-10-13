#!/usr/bin/env bash
set -euo pipefail

missing=0

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'ok      %s\n' "$1"
  else
    printf 'missing %s\n' "$1"
    missing=1
  fi
}

require_command pacman
require_command buildiso
require_command xorriso
require_command grub-mkimage
require_command mksquashfs
require_command mkinitcpio
require_command yq
require_command losetup

if loop_device=$(losetup -f 2>/dev/null); then
  printf 'ok      %s\n' "$loop_device"
else
  printf 'missing usable loop device\n'
  missing=1
fi

if [[ $missing -ne 0 ]]; then
  printf '\nInstall the missing Artix artools/ISO dependencies before building.\n' >&2
  exit 1
fi

printf 'ready   ISO build prerequisites detected\n'
