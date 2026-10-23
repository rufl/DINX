#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
metadata=${1:-}
iso_path=${2:-}

fail() {
  printf 'check_build_metadata: %s\n' "$*" >&2
  exit 1
}

[[ -n "$metadata" ]] || fail "usage: $0 METADATA [ISO]"
[[ -r "$metadata" ]] || fail "metadata is not readable: $metadata"

if [[ -n "$iso_path" ]]; then
  [[ -f "$iso_path" ]] || fail "ISO is not a regular file: $iso_path"
fi
read_value() {
  local key=$1
  sed -n "s/^${key}=//p" "$metadata" | head -n 1
}

require_value() {
  local key=$1
  local pattern=$2
  local value
  value=$(read_value "$key")
  [[ -n "$value" ]] || fail "missing metadata field: $key"
  [[ "$value" =~ $pattern ]] || fail "invalid metadata field $key: $value"
}

[[ "$(read_value schema)" == 'dinx-build-metadata/v1' ]] || fail 'unsupported metadata schema'
require_value repository '^[^[:space:]]+$'
require_value commit '^[0-9a-f]{40}$'
require_value workflow_run '^[0-9]+$'
require_value artix_image '^artixlinux/artixlinux@sha256:[0-9a-f]{64}$'
require_value compression_schema '^dinx-squashfs/v1$'
require_value compression_algorithm '^xz$'
require_value compression_level '^tool-default$'
require_value compression_block '^1M$'
require_value compression_dictionary '^1M$'
require_value compression_bcj '^x86$'
require_value compression_excludes '^kernel-source,pacman-cache,logs$'
require_value compression_wrapper_sha256 '^[0-9a-f]{64}$'
require_value builder_pacman_conf_sha256 '^[0-9a-f]{64}$'
require_value builder_mirrorlist_sha256 '^[0-9a-f]{64}$'
require_value zig_version '^0\.17\.0$'
require_value profile_sha256 '^[0-9a-f]{64}$'
require_value common_profile_sha256 '^[0-9a-f]{64}$'
require_value feature_groups_sha256 '^[0-9a-f]{64}$'
require_value noctty_source_env_sha256 '^[0-9a-f]{64}$'
require_value iso_name '^[^/[:space:]]+\.iso$'
require_value iso_bytes '^[1-9][0-9]*$'
require_value iso_sha512 '^[0-9a-f]{128}$'
require_value package_repository_schema '^dinx-package-repository/v1$'
require_value package_repository_publication '^github-release-assets/v1$'
require_value package_repository_snapshot '^[0-9a-f]{64}$'
require_value package_repository_signing_fingerprint '^[A-Fa-f0-9]{40}$'
require_value package_repository_db_sha256 '^[0-9a-f]{64}$'
require_value package_repository_key_sha256 '^[0-9a-f]{64}$'
require_value package_signing_mode '^(ephemeral-ci|persistent)$'
iso_binding=not-checked
if [[ -n "$iso_path" ]]; then
  actual_iso_bytes=$(stat -c '%s' "$iso_path")
  [[ "$(read_value iso_bytes)" == "$actual_iso_bytes" ]] \
    || fail "metadata ISO size does not match artifact: $(read_value iso_bytes) != $actual_iso_bytes"
  actual_iso_sha512=$(sha512sum "$iso_path" | cut -d ' ' -f 1)
  [[ "$(read_value iso_sha512)" == "$actual_iso_sha512" ]] \
    || fail 'metadata ISO SHA-512 does not match artifact'
  iso_binding=verified
fi

grep -Fqx '[builder-packages]' "$metadata" || fail 'builder package section is missing'
grep -Eq '^iso-profiles [^[:space:]]+$' "$metadata" || fail 'iso-profiles version is missing'
grep -Eq '^mkinitcpio [^[:space:]]+$' "$metadata" || fail 'mkinitcpio version is missing'
grep -Fqx '[all-artix-packages]' "$metadata" || fail 'full package section is missing'
grep -Fqx '[largest-packages]' "$metadata" || fail 'largest package diagnostics section is missing'
grep -Eq '^[0-9]+ KiB[[:space:]]+[^[:space:]]+$' "$metadata" \
  || fail 'largest package diagnostics are missing'

profile_sha=$(sha256sum "$repo_root/distro/iso/iso-profiles/dinx/profile.yaml" | cut -d ' ' -f 1)
[[ "$(read_value profile_sha256)" == "$profile_sha" ]] || fail 'profile checksum does not match the checked-out source'
common_profile_sha=$(sha256sum "$repo_root/distro/iso/iso-profiles/common/common.yaml" | cut -d ' ' -f 1)
[[ "$(read_value common_profile_sha256)" == "$common_profile_sha" ]] || fail 'common profile checksum does not match the checked-out source'
feature_groups_sha=$(sha256sum "$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json" | cut -d ' ' -f 1)
[[ "$(read_value feature_groups_sha256)" == "$feature_groups_sha" ]] || fail 'feature-group checksum does not match the checked-out source'
source_env_sha=$(sha256sum "$repo_root/distro/packages/noctty/source.env" | cut -d ' ' -f 1)
[[ "$(read_value noctty_source_env_sha256)" == "$source_env_sha" ]] || fail 'Noctty source.env checksum does not match the checked-out source'
compression_wrapper_sha=$(sha256sum "$repo_root/scripts/iso-tools/mksquashfs" | cut -d ' ' -f 1)
[[ "$(read_value compression_wrapper_sha256)" == "$compression_wrapper_sha" ]] \
  || fail 'compression wrapper checksum does not match the checked-out source'
checkout_commit=$(git -C "$repo_root" rev-parse HEAD) \
  || fail 'checked-out commit cannot be resolved'
metadata_commit=$(read_value commit)
[[ "$metadata_commit" == "$checkout_commit" ]] \
  || fail "metadata commit does not match checked-out source: $metadata_commit != $checkout_commit"
if [[ -n "${GITHUB_SHA:-}" && "$GITHUB_SHA" != "$checkout_commit" && "$GITHUB_SHA" != "$(printf '%040d' 0)" ]]; then
  fail "GITHUB_SHA does not match checked-out source: $GITHUB_SHA != $checkout_commit"
fi

printf 'build_metadata_contract schema=dinx-build-metadata/v1 commit=%s iso=%s packages=true repository_inputs=true signed_package_repository=true source_checksums=true iso_binding=%s\n' \
  "$(read_value commit)" "$(read_value iso_name)" "$iso_binding"
