#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
smoke="$root/scripts/smoke-install.sh"
qualifier="$root/scripts/qualify-iso.sh"
workflow="$root/.github/workflows/p0-iso.yml"
release_workflow="$root/.github/workflows/release.yml"
install_doc="$root/docs/install.md"
roadmap="$root/docs/roadmap.md"
update_smoke="$root/scripts/smoke_dinx_update.sh"

fail() {
  printf 'check_install_lifecycle: %s\n' "$*" >&2
  exit 1
}
for path in "$smoke" "$qualifier" "$workflow" "$release_workflow" "$install_doc" "$roadmap" "$update_smoke"; do
  [[ -r "$path" ]] || fail "missing $path"
done

bash -n "$smoke" || fail 'installer smoke script has invalid shell syntax'
bash -n "$update_smoke" || fail 'update smoke script has invalid shell syntax'
grep -Fq 'DINX_INSTALL_FIRMWARE' "$smoke" || fail 'firmware-mode selector is missing'
grep -Fq -- '--target=x86_64-efi' "$smoke" || fail 'UEFI GRUB path is missing'
grep -Fq -- '--no-nvram --removable' "$smoke" || fail 'UEFI fallback installation mode is missing'
grep -Fq 'EFI/BOOT/grub.cfg' "$smoke" || fail 'UEFI fallback GRUB config is missing'
grep -Fq -- "-p '(hd0,gpt1)/EFI/BOOT'" "$smoke" || fail 'UEFI GRUB prefix image is missing'
grep -Fq 'part_gpt fat ext2 normal configfile linux' "$smoke" || fail 'UEFI GRUB modules are incomplete'
grep -Fq 'OVMF_CODE' "$smoke" || fail 'UEFI QEMU firmware path is missing'
grep -Fq 'DINX_INSTALL_FIRMWARE=bios' "$qualifier" || fail 'shared ISO qualifier omits BIOS install smoke'
grep -Fq 'DINX_INSTALL_FIRMWARE=uefi' "$qualifier" || fail 'shared ISO qualifier omits UEFI install smoke'
grep -Fq 'scripts/qualify-iso.sh "$DINX_ISO"' "$workflow" || fail 'P0 does not run the shared ISO qualifier'
grep -Fq 'There is no installed-ISO upgrade or filesystem rollback procedure.' "$install_doc" || fail 'installed upgrade/filesystem rollback boundary is not documented'
grep -Fq 'installed-ISO upgrades, filesystem rollback and data preservation remain release gates.' "$roadmap" || fail 'installed upgrade/filesystem rollback release gate is not documented'
grep -Fq 'scripts/smoke_dinx_update.sh' "$workflow" || fail 'package update smoke is not wired'
grep -Fq 'require_persistent_package_signing: true' "$release_workflow" || fail 'release workflow does not require persistent signing'
grep -Fq 'filesystem_rollback=not-claimed' "$update_smoke" || fail 'package rollback boundary is not explicit'
printf 'install_lifecycle_contract=bios_uefi_smokes=wired package_update_smoke=wired installed_runtime=checked_during_qualification installed_iso_upgrade=unsupported filesystem_rollback=unsupported\n'
