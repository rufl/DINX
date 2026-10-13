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
require_command modprobe

if [[ -e /dev/loop-control ]]; then
  printf 'ok      /dev/loop-control\n'
else
  printf 'missing /dev/loop-control\n'
  missing=1
fi

if [[ $missing -ne 0 ]]; then
  printf '\nInstall the missing Artix artools/ISO dependencies before building.\n' >&2
  exit 1
fi

printf 'ready   ISO build prerequisites detected\n'
