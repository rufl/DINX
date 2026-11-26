#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
build_script="$root/scripts/build-iso.sh"

fail() {
  printf 'check_dinx_iso_identity: %s\n' "$*" >&2
  exit 1
}

[[ -r "$build_script" ]] || fail "missing ISO build wrapper: $build_script"
grep -Fq 'DINX_$(date +%Y%m)' "$build_script" \
  || fail 'DINX ISO volume label override is missing'
grep -Fq 'local vars=("dinx" "${initsys}" "${iso_version}" "${target_arch}") name' "$build_script" \
  || fail 'DINX ISO filename prefix override is missing'
grep -Fq 'clean_first=true' "$build_script" \
  || fail 'wrapper no longer anchors the ISO identity after Artix configuration loading'
grep -Fq 'label_replacements++' "$build_script" \
  || fail 'wrapper does not inject the DINX ISO volume label'
grep -Fq '"$private_buildiso" > "$private_iso_filename_tmp"' "$build_script" \
  || fail 'wrapper does not patch the private buildiso filename function'
grep -Fq -- '-p dinx' "$build_script" \
  || fail 'ISO build does not select the DINX profile'
printf 'dinx_iso_identity_contract volume_id=DINX_YYYYMM filename=dinx-dinit-YYYYMMDD-x86_64.iso upstream_prefix_removed=true\n'
