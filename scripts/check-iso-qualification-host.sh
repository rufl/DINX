#!/usr/bin/env bash
set -euo pipefail

mode=${1:-full}
shift || true
build_paths=()
while (($#)); do
  case "$1" in
    --build-path)
      (($# >= 2)) || { printf 'iso-qualification-host: --build-path needs a path\n' >&2; exit 1; }
      build_paths+=("$2")
      shift 2
      ;;
    *)
      printf 'iso-qualification-host: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

fail() {
  printf 'iso-qualification-host: %s\n' "$*" >&2
  exit 1
}

case "$mode" in
  static|full) ;;
  *) fail 'usage: scripts/check-iso-qualification-host.sh [static|full] [--build-path PATH ...]' ;;
esac

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required host command not found: $1"
}

for command in awk cmp df grep jq mktemp python3 realpath rm sha256sum sha512sum stat unsquashfs xorriso zstd; do
  require_command "$command"
done
if [[ "$mode" == full ]]; then
  if ((${#build_paths[@]} == 0)); then
    build_paths=("${DINX_LOCAL_BUILD_DIR:-${DINX_ISO_OUTPUT:-${TMPDIR:-/tmp}}}")
  fi
  min_build_kb=${DINX_MIN_BUILD_KB:-10485760}
  min_build_inodes=${DINX_MIN_BUILD_INODES:-100000}
  [[ "$min_build_kb" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_MIN_BUILD_KB must be a positive integer'
  [[ "$min_build_inodes" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_MIN_BUILD_INODES must be a positive integer'
  for requested_path in "${build_paths[@]}"; do
    [[ -n "$requested_path" ]] || fail 'build path cannot be empty'
    build_path=$(realpath -m -- "$requested_path") || fail "cannot resolve build path: $requested_path"
    while [[ ! -e "$build_path" ]]; do
      parent=$(dirname -- "$build_path")
      [[ "$parent" != "$build_path" ]] || fail "no existing parent for build path: $requested_path"
      build_path=$parent
    done
    available_kb=$(df -Pk "$build_path" | awk 'NR == 2 {print $4}')
    available_inodes=$(df -Pi "$build_path" | awk 'NR == 2 {print $4}')
    [[ "$available_kb" =~ ^[0-9]+$ && "$available_kb" -ge "$min_build_kb" ]] \
      || fail "insufficient build space at $requested_path (filesystem path $build_path): ${available_kb:-unknown} KiB available; need at least $min_build_kb KiB"
    [[ "$available_inodes" =~ ^[0-9]+$ && "$available_inodes" -ge "$min_build_inodes" ]] \
      || fail "insufficient build inodes at $requested_path (filesystem path $build_path): ${available_inodes:-unknown} available; need at least $min_build_inodes"
    printf 'iso-qualification-host: build storage passed path=%s available_kib=%s available_inodes=%s\n' \
      "$requested_path" "$available_kb" "$available_inodes"
  done
fi

if [[ "$mode" == static ]]; then
  printf '%s\n' 'iso-qualification-host: static qualification prerequisites passed'
  exit 0
fi

for command in blkid chroot grub-install grub-mkconfig losetup mkfs.ext4 mount mkfs.fat qemu-system-x86_64 sfdisk socat tesseract timeout truncate umount unsquashfs xorriso; do
  require_command "$command"
done
if [[ $EUID -ne 0 ]]; then
  require_command sudo
fi
if [[ ! -e /dev/loop-control ]] || ! (losetup --find >/dev/null 2>&1); then
  fail 'loop-device support is unavailable; provide /dev/loop-control and a usable loop device before building packages'
fi

ocr_language=${DINX_QEMU_OCR_LANG:-eng}
[[ "$ocr_language" =~ ^[[:alnum:]_+-]+$ ]] || fail 'DINX_QEMU_OCR_LANG contains unsupported characters'
languages=$(tesseract --list-langs 2>&1) || fail 'Tesseract could not list installed language data'
IFS='+' read -r -a requested_languages <<< "$ocr_language"
for language in "${requested_languages[@]}"; do
  grep -Fqx "$language" <<< "$languages" \
    || fail "Tesseract language data '$language' is missing; install tesseract-ocr-eng or set DINX_QEMU_OCR_LANG to an installed model"
done

qemu_devices=$(qemu-system-x86_64 -device help 2>&1) \
  || fail 'qemu-system-x86_64 could not enumerate emulated devices'
grep -Fq 'virtio-vga' <<< "$qemu_devices" \
  || fail 'host QEMU lacks the virtio-vga display device required for the live-session graphics smoke'

ovmf_code=${DINX_INSTALL_OVMF_CODE:-}
ovmf_vars=${DINX_INSTALL_OVMF_VARS:-}
if [[ -z "$ovmf_code" ]]; then
  for candidate in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd; do
    if [[ -r "$candidate" ]]; then
      ovmf_code=$candidate
      break
    fi
  done
fi
if [[ -z "$ovmf_vars" ]]; then
  for candidate in \
    /usr/share/OVMF/OVMF_VARS_4M.fd \
    /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/edk2/x64/OVMF_VARS.4m.fd; do
    if [[ -r "$candidate" ]]; then
      ovmf_vars=$candidate
      break
    fi
  done
fi
[[ -r "$ovmf_code" ]] || fail 'OVMF code firmware is missing; install the host OVMF package or set DINX_INSTALL_OVMF_CODE'
[[ -r "$ovmf_vars" ]] || fail 'OVMF variables template is missing; install the host OVMF package or set DINX_INSTALL_OVMF_VARS'
printf 'iso-qualification-host: full qualification prerequisites passed (OCR=%s, virtio-vga, OVMF)\n' "$ocr_language"
