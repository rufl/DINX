#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
smoke="$root/scripts/smoke-install.sh"
workflow="$root/.github/workflows/p0-iso.yml"
install_doc="$root/docs/install.md"
roadmap="$root/docs/roadmap.md"

fail() {
  printf 'check_install_lifecycle: %s\n' "$*" >&2
  exit 1
}

for path in "$smoke" "$workflow" "$install_doc" "$roadmap"; do
  [[ -r "$path" ]] || fail "missing $path"
done

bash -n "$smoke" || fail 'installer smoke script has invalid shell syntax'
grep -Fq 'DINX_INSTALL_FIRMWARE' "$smoke" || fail 'firmware-mode selector is missing'
grep -Fq -- '--target=x86_64-efi' "$smoke" || fail 'UEFI GRUB path is missing'
grep -Fq 'grub-mkimage' "$smoke" || fail 'UEFI embedded GRUB configuration is missing'
grep -Fq 'dinx-grub-uefi.cfg' "$smoke" || fail 'UEFI embedded GRUB config fixture is missing'
grep -Fq 'OVMF_CODE' "$smoke" || fail 'UEFI QEMU firmware path is missing'
grep -Fq 'DINX_INSTALL_FIRMWARE=bios' "$workflow" || fail 'BIOS install smoke is not wired'
grep -Fq 'DINX_INSTALL_FIRMWARE=uefi' "$workflow" || fail 'UEFI install smoke is not wired'
grep -Fq 'There is no upgrade or rollback procedure.' "$install_doc" || fail 'unsupported upgrade/rollback boundary is not documented'
grep -Fq 'hardware installation, upgrades and rollback remain release gates.' "$roadmap" || fail 'upgrade/rollback release gate is not documented'

printf 'install_lifecycle_contract=bios=true uefi=true upgrade=unsupported rollback=unsupported\n'
