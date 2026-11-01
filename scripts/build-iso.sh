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

artools_paths=$(awk -F"'" '
  /^LIBDIR=/ {
    libdir = $2
    libdir_count++
  }
  /^DATADIR=/ {
    datadir = $2
    datadir_count++
  }
  END {
    if (libdir_count != 1 || datadir_count != 1 || libdir == "" || datadir == "") exit 1
    print libdir
    print datadir
  }
' "$buildiso_path") || fail "cannot resolve Artix buildiso directories: $buildiso_path"
mapfile -t artools_paths <<< "$artools_paths"
[[ ${#artools_paths[@]} -eq 2 ]] || fail "invalid Artix buildiso directories: $buildiso_path"
artools_lib_dir=${artools_paths[0]}
artools_data_dir=${artools_paths[1]}
case "$artools_lib_dir" in
  "$artools_data_dir"/*) artools_lib_relative=${artools_lib_dir#"$artools_data_dir"/} ;;
  *) fail "Artix library directory is outside its data directory: $artools_lib_dir" ;;
esac
artools_initcpio_helper="$artools_lib_dir/iso/initcpio.sh"
[[ -r "$artools_initcpio_helper" ]] \
  || fail "missing Artix initramfs builder helper: $artools_initcpio_helper"
[[ -x "$repo_root/scripts/patch-artix-initcpio.sh" ]] \
  || fail "missing executable initramfs patcher: $repo_root/scripts/patch-artix-initcpio.sh"

private_buildiso_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-buildiso.XXXXXX")
trap 'rm -rf -- "$private_buildiso_dir"' EXIT
private_artools_data="$private_buildiso_dir/data"
mkdir "$private_artools_data"
cp -a -- "$artools_data_dir/." "$private_artools_data/"

private_initcpio_helper="$private_artools_data/$artools_lib_relative/iso/initcpio.sh"
"$repo_root/scripts/patch-artix-initcpio.sh" --patch-artix-helper "$private_initcpio_helper"

private_buildiso="$private_buildiso_dir/buildiso"
awk '
  /^LIBDIR=/ {
    print "LIBDIR=\"${DINX_PRIVATE_LIBDIR:?}\""
    libdir_replacements++
    next
  }
  /^DATADIR=/ {
    print "DATADIR=\"${DINX_PRIVATE_DATADIR:?}\""
    datadir_replacements++
    next
  }
  { print }
  END {
    if (libdir_replacements != 1 || datadir_replacements != 1) exit 1
  }
' "$buildiso_path" > "$private_buildiso" \
  || fail "unsupported Artix buildiso directory layout: $buildiso_path"
chmod --reference="$buildiso_path" "$private_buildiso"

DINX_INITRAMFS_PATCHER="$repo_root/scripts/patch-artix-initcpio.sh" \
DINX_PRIVATE_LIBDIR="$private_artools_data/$artools_lib_relative" \
DINX_PRIVATE_DATADIR="$private_artools_data" \
PATH="$iso_tools_path" WORKSPACE_DIR="$workspace_dir" \
  "$private_buildiso" \
  -p dinx \
  -i dinit \
  -r "$chroots_dir" \
  -t "$output_dir" \
  "$@"
