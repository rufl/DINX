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
    DINX_ISO_OUTPUT="$output_dir" \
    DINX_ISO_CHROOTS="$chroots_dir" \
    "$repo_root/scripts/build-iso.sh" \
    "$@"
fi

ensure_loop_support

artools_data_dir=$(awk -F"'" '
  /^DATADIR=/ {
    print $2
    count++
  }
  END {
    if (count != 1) exit 1
  }
' "$buildiso_path") || fail "cannot resolve Artix buildiso data directory: $buildiso_path"
artools_mkinitcpio_config="$artools_data_dir/mkinitcpio.conf"
[[ -r "$artools_mkinitcpio_config" ]] \
  || fail "missing Artix initramfs configuration: $artools_mkinitcpio_config"

private_buildiso_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-buildiso.XXXXXX")
trap 'rm -rf -- "$private_buildiso_dir"' EXIT
mkdir "$private_buildiso_dir/data"
cp -a -- "$artools_data_dir/." "$private_buildiso_dir/data/"

patched_mkinitcpio_config="$private_buildiso_dir/mkinitcpio.conf"
awk '
  /^MODULES=\(/ {
    if (modules_seen || $0 !~ /\)$/) exit 1
    if (index($0, "vmwgfx") == 0) sub(/\)$/, " vmwgfx)")
    if (index($0, "vboxvideo") == 0) sub(/\)$/, " vboxvideo)")
    modules_seen++
    print
    next
  }
  { print }
  END {
    if (modules_seen != 1) exit 1
  }
' "$private_buildiso_dir/data/mkinitcpio.conf" > "$patched_mkinitcpio_config" \
  || fail "unsupported MODULES layout in $artools_mkinitcpio_config"
chmod --reference="$artools_mkinitcpio_config" "$patched_mkinitcpio_config"
mv -- "$patched_mkinitcpio_config" "$private_buildiso_dir/data/mkinitcpio.conf"

private_buildiso="$private_buildiso_dir/buildiso"
awk -v datadir="$private_buildiso_dir/data" '
  /^DATADIR=/ {
    printf "DATADIR=\"%s\"\n", datadir
    replacements++
    next
  }
  { print }
  END {
    if (replacements != 1) exit 1
  }
' "$buildiso_path" > "$private_buildiso" \
  || fail "unsupported DATADIR layout in $buildiso_path"
chmod --reference="$buildiso_path" "$private_buildiso"

PATH="$iso_tools_path" WORKSPACE_DIR="$workspace_dir" \
  "$private_buildiso" \
  -p dinx \
  -i dinit \
  -r "$chroots_dir" \
  -t "$output_dir" \
  "$@"
