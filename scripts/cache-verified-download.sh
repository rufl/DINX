#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'cache-verified-download: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 3 ]] || fail 'usage: scripts/cache-verified-download.sh DESTINATION URL SHA256'
destination=$1
url=$2
expected_sha256=$3
[[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] || fail 'SHA256 must be 64 lowercase hexadecimal characters'
command -v curl >/dev/null 2>&1 || fail 'required command not found: curl'
command -v sha256sum >/dev/null 2>&1 || fail 'required command not found: sha256sum'
command -v mktemp >/dev/null 2>&1 || fail 'required command not found: mktemp'
command -v mv >/dev/null 2>&1 || fail 'required command not found: mv'
command -v rm >/dev/null 2>&1 || fail 'required command not found: rm'

parent_dir=$(dirname -- "$destination")
mkdir -p -- "$parent_dir"
if [[ -f "$destination" && ! -L "$destination" ]]; then
  actual_sha256=$(sha256sum -- "$destination")
  actual_sha256=${actual_sha256%% *}
  if [[ "$actual_sha256" == "$expected_sha256" ]]; then
    printf 'cache-verified-download: cache-hit sha256=%s path=%s\n' "$expected_sha256" "$destination"
    exit 0
  fi
  printf 'cache-verified-download: evicting checksum-mismatched cache entry: %s\n' "$destination" >&2
fi
rm -f -- "$destination"
temporary=$(mktemp "$parent_dir/.download.XXXXXXXX")
trap 'rm -f -- "$temporary"' EXIT
curl --fail --silent --show-error --location --retry 3 --output "$temporary" "$url" \
  || fail "download failed: $url"
actual_sha256=$(sha256sum -- "$temporary")
actual_sha256=${actual_sha256%% *}
[[ "$actual_sha256" == "$expected_sha256" ]] \
  || fail "SHA256 mismatch for $url: expected $expected_sha256, got $actual_sha256"
mv -f -- "$temporary" "$destination"
if [[ -n ${DINX_CACHE_DIRTY_MARKER:-} ]]; then
  mkdir -p -- "$(dirname -- "$DINX_CACHE_DIRTY_MARKER")"
  touch -- "$DINX_CACHE_DIRTY_MARKER"
fi
trap - EXIT
printf 'cache-verified-download: downloaded and verified sha256=%s path=%s\n' "$actual_sha256" "$destination"
