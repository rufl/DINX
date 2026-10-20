#!/usr/bin/env bash
set -euo pipefail

report=${1:-}
build_metadata=${2:-}

fail() {
  printf 'check_dinx_hardware_evidence: %s\n' "$*" >&2
  exit 1
}

[[ -n "$report" ]] || fail "usage: $0 REPORT [BUILD_METADATA]"
[[ -r "$report" ]] || fail "report is not readable: $report"
if [[ -n "$build_metadata" ]]; then
  [[ -r "$build_metadata" ]] || fail "build metadata is not readable: $build_metadata"
fi

read_file_value() {
  local file=$1
  local key=$2
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

read_value() {
  read_file_value "$report" "$1"
}

require_value() {
  local key=$1
  local pattern=$2
  local value
  local count
  count=$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$report")
  [[ "$count" == 1 ]] || fail "evidence field must occur exactly once: $key"
  value=$(read_value "$key")
  [[ -n "$value" ]] || fail "missing evidence field: $key"
  [[ "$value" =~ $pattern ]] || fail "invalid evidence field $key: $value"
}

require_value schema '^dinx-alpha7-hardware-report/v1$'
require_value generated_utc '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
require_value machine_role '^(desktop|laptop|bc250)$'
require_value firmware_mode '^(bios|uefi)$'
require_value release_tag '^v[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9._-]+$'
require_value build_commit '^[0-9a-f]{40}$'
require_value package_repository_snapshot '^[0-9a-f]{64}$'
require_value report_complete '^true$'

for result in \
  result_real_drm_session \
  result_steam_authentication \
  result_commercial_game_launch \
  result_controller_input \
  result_pipewire_game_audio \
  result_suspend_resume \
  result_physical_brightness \
  result_gpu_recovery \
  result_update_path; do
  require_value "$result" '^pass$'
done

metadata_binding=not-provided
if [[ -n "$build_metadata" ]]; then
  [[ "$(read_file_value "$build_metadata" schema)" == 'dinx-build-metadata/v1' ]] \
    || fail 'unsupported build metadata schema'
  metadata_commit=$(read_file_value "$build_metadata" commit)
  metadata_snapshot=$(read_file_value "$build_metadata" package_repository_snapshot)
  [[ "$metadata_commit" =~ ^[0-9a-f]{40}$ ]] || fail 'build metadata commit is invalid'
  [[ "$metadata_snapshot" =~ ^[0-9a-f]{64}$ ]] || fail 'build metadata package snapshot is invalid'
  [[ "$(read_value build_commit)" == "$metadata_commit" ]] \
    || fail 'report build commit does not match build metadata'
  [[ "$(read_value package_repository_snapshot)" == "$metadata_snapshot" ]] \
    || fail 'report package snapshot does not match build metadata'
  metadata_binding=verified
fi

printf 'dinx_hardware_evidence role=%s firmware=%s release=%s results=pass metadata=%s filesystem_rollback=unsupported\n' \
  "$(read_value machine_role)" "$(read_value firmware_mode)" "$(read_value release_tag)" "$metadata_binding"
