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

require_command pacman
require_command xorriso
require_command buildiso

profile_dir="$workspace_dir/iso-profiles/dinx"
[[ -f "$profile_dir/profile.yaml" ]] || fail "missing DINX profile: $profile_dir/profile.yaml"

mkdir -p "$output_dir"
buildiso_path=$(command -v buildiso)

if [[ $EUID -ne 0 ]]; then
  require_command sudo
  sudo modprobe loop
  exec sudo env \
    WORKSPACE_DIR="$workspace_dir" \
    "$buildiso_path" \
    -p dinx \
    -i dinit \
    -r "$chroots_dir" \
    -t "$output_dir" \
    "$@"
fi

modprobe loop
exec "$buildiso_path" \
  -p dinx \
  -i dinit \
  -r "$chroots_dir" \
  -t "$output_dir" \
  "$@"
