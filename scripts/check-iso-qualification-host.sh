#!/usr/bin/env bash
set -euo pipefail

mode=${1:-full}

fail() {
  printf 'iso-qualification-host: %s\n' "$*" >&2
  exit 1
}

[[ $# -le 1 ]] || fail 'usage: scripts/check-iso-qualification-host.sh [static|full]'
case "$mode" in
  static|full) ;;
  *) fail 'mode must be static or full' ;;
esac

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required host command not found: $1"
}

for command in awk bsdtar cmp grep mktemp rm sha256sum sha512sum stat unsquashfs xorriso; do
  require_command "$command"
done

if [[ "$mode" == static ]]; then
  printf '%s\n' 'iso-qualification-host: static qualification prerequisites passed'
  exit 0
fi

for command in blkid chroot grub-install grub-mkconfig losetup mkfs.ext4 mount mkfs.fat qemu-system-x86_64 sfdisk socat tesseract timeout truncate umount unsquashfs xorriso; do
  require_command "$command"
done
require_command python3
if [[ $EUID -ne 0 ]]; then
  require_command sudo
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
grep -Fq 'vmware-svga' <<< "$qemu_devices" \
  || fail 'host QEMU lacks the vmware-svga display device required for VirtualBox graphics proxy smoke'

ovmf_code=${DINX_INSTALL_OVMF_CODE:-}
ovmf_vars=${DINX_INSTALL_OVMF_VARS:-}
if [[ -z "$ovmf_code" ]]; then
  for candidate in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
    if [[ -r "$candidate" ]]; then
      ovmf_code=$candidate
      break
    fi
  done
fi
if [[ -z "$ovmf_vars" ]]; then
  for candidate in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do
    if [[ -r "$candidate" ]]; then
      ovmf_vars=$candidate
      break
    fi
  done
fi
[[ -r "$ovmf_code" ]] || fail 'OVMF code firmware is missing; install the host OVMF package or set DINX_INSTALL_OVMF_CODE'
[[ -r "$ovmf_vars" ]] || fail 'OVMF variables template is missing; install the host OVMF package or set DINX_INSTALL_OVMF_VARS'
printf 'iso-qualification-host: full qualification prerequisites passed (OCR=%s, vmware-svga, OVMF)\n' "$ocr_language"
