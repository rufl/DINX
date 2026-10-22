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
common_profile="$workspace_dir/iso-profiles/common/common.yaml"
iso_tools_dir="$repo_root/scripts/iso-tools"
[[ -f "$profile_dir/profile.yaml" ]] || fail "missing DINX profile: $profile_dir/profile.yaml"
[[ -f "$common_profile" ]] || fail "missing compact common profile: $common_profile"
[[ -x "$iso_tools_dir/mksquashfs" ]] || fail "missing executable ISO compression wrapper: $iso_tools_dir/mksquashfs"
iso_tools_path="$iso_tools_dir:$PATH"
buildiso_path=$(command -v buildiso)

mkdir -p "$output_dir"

if [[ $EUID -ne 0 ]]; then
  require_command sudo
  ensure_loop_support_with_sudo
  exec sudo env \
    PATH="$iso_tools_path" \
    WORKSPACE_DIR="$workspace_dir" \
    "$buildiso_path" \
    -p dinx \
    -i dinit \
    -r "$chroots_dir" \
    -t "$output_dir" \
    "$@"
fi

ensure_loop_support
exec env \
  PATH="$iso_tools_path" \
  WORKSPACE_DIR="$workspace_dir" \
  "$buildiso_path" \
  -p dinx \
  -i dinit \
  -r "$chroots_dir" \
  -t "$output_dir" \
  "$@"
