#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
metadata=${1:-}
repository_dir=${2:-}
release_tag=${3:-}
release_base_url=${4:-}
iso_path=${5:-}

fail() {
  printf 'check_dinx_release_preflight: %s\n' "$*" >&2
  exit 1
}

[[ -n "$metadata" && -n "$repository_dir" && -n "$release_tag" && -n "$iso_path" ]] \
  || fail "usage: $0 BUILD_METADATA REPOSITORY_DIR RELEASE_TAG [RELEASE_BASE_URL] ISO"
[[ -r "$metadata" ]] || fail "build metadata is not readable: $metadata"
[[ -f "$iso_path" ]] || fail "ISO is not a regular file: $iso_path"
[[ -d "$repository_dir" ]] || fail "repository directory does not exist: $repository_dir"
[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9._-]+$ ]] \
  || fail "release tag is not alpha/beta/rc shaped: $release_tag"

for command in awk cmp sha256sum; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

read_value() {
  local file=$1
  local key=$2
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

require_value() {
  local file=$1
  local key=$2
  local pattern=$3
  local value
  value=$(read_value "$file" "$key")
  [[ -n "$value" ]] || fail "missing metadata field: $key"
  [[ "$value" =~ $pattern ]] || fail "invalid metadata field $key: $value"
}

"$repo_root/scripts/check_build_metadata.sh" "$metadata" "$iso_path" >/dev/null
"$repo_root/scripts/check_dinx_package_repository.sh" "$repository_dir" >/dev/null

require_value "$metadata" package_repository_channel '^stable$'
require_value "$metadata" package_signing_mode '^persistent$'
require_value "$metadata" package_repository_publication '^github-release-assets/v1$'
require_value "$metadata" package_repository_snapshot '^[0-9a-f]{64}$'
require_value "$metadata" package_repository_signing_fingerprint '^[A-Fa-f0-9]{40}$'
require_value "$metadata" package_repository_db_sha256 '^[0-9a-f]{64}$'
require_value "$metadata" package_repository_key_sha256 '^[0-9a-f]{64}$'

repository_metadata="$repository_dir/dinx-repository-metadata.txt"
[[ -r "$repository_metadata" ]] || fail "repository metadata is missing: $repository_metadata"
repository_snapshot=$(read_value "$repository_metadata" snapshot)
repository_fingerprint=$(read_value "$repository_metadata" signing_fingerprint)
metadata_snapshot=$(read_value "$metadata" package_repository_snapshot)
metadata_fingerprint=$(read_value "$metadata" package_repository_signing_fingerprint)
[[ "$(read_value "$repository_metadata" channel)" == stable ]] \
  || fail 'published repository metadata is not stable'
[[ "$repository_snapshot" == "$metadata_snapshot" ]] \
  || fail 'published repository snapshot does not match build metadata'
[[ "${repository_fingerprint,,}" == "${metadata_fingerprint,,}" ]] \
  || fail 'published repository fingerprint does not match build metadata'

actual_db_sha256=$(sha256sum "$repository_dir/dinx.db.tar.gz" | cut -d ' ' -f 1)
actual_key_sha256=$(sha256sum "$repository_dir/dinx-package-signing-key.gpg" | cut -d ' ' -f 1)
[[ "$actual_db_sha256" == "$(read_value "$metadata" package_repository_db_sha256)" ]] \
  || fail 'published repository database checksum does not match build metadata'
[[ "$actual_key_sha256" == "$(read_value "$metadata" package_repository_key_sha256)" ]] \
  || fail 'published repository key checksum does not match build metadata'

[[ -s "$repository_dir/dinx.db" ]] || fail 'release repository database alias is missing'
[[ -s "$repository_dir/dinx.db.sig" ]] || fail 'release repository database signature alias is missing'
[[ ! -L "$repository_dir/dinx.db" && ! -L "$repository_dir/dinx.db.sig" ]] \
  || fail 'release repository database aliases must be regular files'
cmp -s "$repository_dir/dinx.db.tar.gz" "$repository_dir/dinx.db" \
  || fail 'release repository database alias differs from the signed database'
cmp -s "$repository_dir/dinx.db.tar.gz.sig" "$repository_dir/dinx.db.sig" \
  || fail 'release repository database signature alias differs from the signed signature'

if [[ -n "$release_base_url" ]]; then
  [[ "$release_base_url" == */"$release_tag" ]] \
    || fail "release base URL does not end with $release_tag: $release_base_url"
  release_base_prefix=${release_base_url%/"$release_tag"}
  [[ "$release_base_prefix" =~ ^https://github\.com/[^/]+/[^/]+/releases/download$ ]] \
    || fail "invalid GitHub release base URL: $release_base_url"
fi

printf 'dinx_release_preflight tag=%s channel=stable signing=persistent repository=release-assets snapshot=%s packages=true aliases=true update_smoke=true\n' \
  "$release_tag" "$repository_snapshot"
