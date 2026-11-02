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
printf 'immutable archive payload v1\n' > "$source_file"
sha_v1=$(sha256sum "$source_file")
sha_v1=${sha_v1%% *}
"$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v1"
cmp -s "$source_file" "$cache_file" || fail 'cold download did not produce the source bytes'

printf 'changed source must not replace a verified cache hit\n' > "$source_file"
"$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v1" \
  > "$tmp_dir/cache-hit.log"
grep -Fq 'cache-hit' "$tmp_dir/cache-hit.log" || fail 'matching cache entry was not reused'
grep -Fq 'immutable archive payload v1' "$cache_file" \
  || fail 'cache hit trusted changed URL content instead of the pinned checksum'

sha_v2=$(sha256sum "$source_file")
sha_v2=${sha_v2%% *}
printf 'corrupt cache content\n' > "$cache_file"
"$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v2"
cmp -s "$source_file" "$cache_file" || fail 'checksum-mismatched cache entry was not replaced'

if "$script_dir/cache-verified-download.sh" "$cache_file" "file://$source_file" "$sha_v1" \
  > "$tmp_dir/wrong-checksum.log" 2>&1; then
  fail 'download with an incorrect expected checksum succeeded'
fi
[[ ! -e "$cache_file" ]] || fail 'failed checksum left an unverified destination file'
printf '%s\n' 'smoke-cache-verified-download: cold fetch, verified hit, corrupt-entry repair and checksum rejection passed'
