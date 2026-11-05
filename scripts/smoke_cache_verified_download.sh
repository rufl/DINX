#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
  printf 'smoke-cache-verified-download: %s\n' "$*" >&2
  exit 1
}

source_file="$tmp_dir/source.bin"
cache_file="$tmp_dir/cache/toolchain.bin"
dirty_marker="$tmp_dir/cache/build-data-updated"
printf 'immutable archive payload v1\n' > "$source_file"
sha_v1=$(sha256sum "$source_file")
sha_v1=${sha_v1%% *}
DINX_CACHE_DIRTY_MARKER="$dirty_marker" \
  "$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v1"
cmp -s "$source_file" "$cache_file" || fail 'cold download did not produce the source bytes'
[[ -f "$dirty_marker" ]] || fail 'cold download did not mark the cache as changed'

rm -f -- "$dirty_marker"
printf 'changed source must not replace a verified cache hit\n' > "$source_file"
DINX_CACHE_DIRTY_MARKER="$dirty_marker" \
  "$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v1" \
  > "$tmp_dir/cache-hit.log"
grep -Fq 'cache-hit' "$tmp_dir/cache-hit.log" || fail 'matching cache entry was not reused'
[[ ! -e "$dirty_marker" ]] || fail 'cache hit marked the cache as changed'
grep -Fq 'immutable archive payload v1' "$cache_file" \
  || fail 'cache hit trusted changed URL content instead of the pinned checksum'

sha_v2=$(sha256sum "$source_file")
sha_v2=${sha_v2%% *}
rm -f -- "$dirty_marker"
printf 'corrupt cache content\n' > "$cache_file"
DINX_CACHE_DIRTY_MARKER="$dirty_marker" \
  "$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v2"
cmp -s "$source_file" "$cache_file" || fail 'checksum-mismatched cache entry was not replaced'
[[ -f "$dirty_marker" ]] || fail 'cache repair did not mark the cache as changed'
rm -f -- "$dirty_marker"
if "$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v1" \
  > "$tmp_dir/wrong-checksum.log" 2>&1; then
  fail 'download with an incorrect expected checksum succeeded'
fi
[[ ! -e "$cache_file" ]] || fail 'failed checksum left an unverified destination file'
[[ ! -e "$dirty_marker" ]] || fail 'rejected checksum marked the cache as changed'
printf '%s\n' 'smoke-cache-verified-download: cold fetch, verified hit, corrupt-entry repair and checksum rejection passed'
