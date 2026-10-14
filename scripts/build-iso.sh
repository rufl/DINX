#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workspace_dir="$repo_root/distro/iso"
output_dir=${DINX_ISO_OUTPUT:-"$repo_root/dist/iso"}
chroots_dir=${DINX_ISO_CHROOTS:-/var/lib/artools/buildiso}

fail() {
  printf 'build-iso: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

ensure_loop_support() {
  if losetup -f >/dev/null 2>&1; then
    return
  fi

  modprobe loop
  losetup -f >/dev/null 2>&1 || fail "loop device support is unavailable"
}

ensure_loop_support_with_sudo() {
  if sudo losetup -f >/dev/null 2>&1; then
    return
  fi

  sudo modprobe loop
  sudo losetup -f >/dev/null 2>&1 || fail "loop device support is unavailable"
}

require_command losetup

require_command pacman
require_command xorriso
require_command buildiso

profile_dir="$workspace_dir/iso-profiles/dinx"
[[ -f "$profile_dir/profile.yaml" ]] || fail "missing DINX profile: $profile_dir/profile.yaml"

mkdir -p "$output_dir"
buildiso_path=$(command -v buildiso)

run_buildiso() {
  if [[ $EUID -ne 0 ]]; then
    sudo env \
      WORKSPACE_DIR="$workspace_dir" \
      "$buildiso_path" \
      -p dinx \
      -i dinit \
      -r "$chroots_dir" \
      -t "$output_dir" \
      "$@"
  else
    env WORKSPACE_DIR="$workspace_dir" "$buildiso_path" \
      -p dinx \
      -i dinit \
      -r "$chroots_dir" \
      -t "$output_dir" \
      "$@"
  fi
}

run_buildiso_phase() {
  local status
  set +e
  run_buildiso "$@"
  status=$?
  set -e
  [[ $status -eq 0 || $status -eq 1 ]] || return "$status"
}

strip_systemd_payload() {
  local image_root
  for image_root in \
    "$chroots_dir/dinx/artix/rootfs" \
    "$chroots_dir/dinx/artix/livefs"; do
    [[ -d "$image_root" ]] || continue
    if [[ $EUID -ne 0 ]]; then
      sudo rm -rf -- "$image_root/etc/systemd" "$image_root/usr/lib/systemd"
    else
      rm -rf -- "$image_root/etc/systemd" "$image_root/usr/lib/systemd"
    fi
  done
}

if [[ $EUID -ne 0 ]]; then
  require_command sudo
  ensure_loop_support_with_sudo
fi

run_buildiso_phase -x "$@"
strip_systemd_payload
run_buildiso_phase -z "$@"
