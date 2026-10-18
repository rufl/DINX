#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
metadata=${1:-}

fail() {
  printf 'check_build_metadata: %s\n' "$*" >&2
  exit 1
}

[[ -n "$metadata" ]] || fail "usage: $0 METADATA"
[[ -r "$metadata" ]] || fail "metadata is not readable: $metadata"

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
require_value builder_pacman_conf_sha256 '^[0-9a-f]{64}$'
require_value builder_mirrorlist_sha256 '^[0-9a-f]{64}$'
require_value zig_version '^0\.17\.0$'
require_value profile_sha256 '^[0-9a-f]{64}$'
require_value noctty_source_env_sha256 '^[0-9a-f]{64}$'
require_value iso_name '^[^/[:space:]]+\.iso$'
require_value iso_bytes '^[1-9][0-9]*$'
require_value iso_sha512 '^[0-9a-f]{128}$'

grep -Fqx '[builder-packages]' "$metadata" || fail 'builder package section is missing'
grep -Eq '^iso-profiles [^[:space:]]+$' "$metadata" || fail 'iso-profiles version is missing'
grep -Eq '^mkinitcpio [^[:space:]]+$' "$metadata" || fail 'mkinitcpio version is missing'
grep -Fqx '[all-artix-packages]' "$metadata" || fail 'full package section is missing'

profile_sha=$(sha256sum "$repo_root/distro/iso/iso-profiles/dinx/profile.yaml" | cut -d ' ' -f 1)
[[ "$(read_value profile_sha256)" == "$profile_sha" ]] || fail 'profile checksum does not match the checked-out source'
source_env_sha=$(sha256sum "$repo_root/distro/packages/noctty/source.env" | cut -d ' ' -f 1)
[[ "$(read_value noctty_source_env_sha256)" == "$source_env_sha" ]] || fail 'Noctty source.env checksum does not match the checked-out source'
if [[ -n "${GITHUB_SHA:-}" && "$(read_value commit)" != "$GITHUB_SHA" ]]; then
  fail "metadata commit does not match GITHUB_SHA: $(read_value commit) != $GITHUB_SHA"
fi

printf 'build_metadata_contract schema=dinx-build-metadata/v1 commit=%s iso=%s packages=true repository_inputs=true source_checksums=true\n' \
  "$(read_value commit)" "$(read_value iso_name)"
