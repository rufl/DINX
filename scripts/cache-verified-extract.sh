#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'cache-verified-extract: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 5 ]] || fail 'usage: scripts/cache-verified-extract.sh ARCHIVE SHA256 VERSION BINARY_RELATIVE_PATH DESTINATION'
archive=$1
expected_sha256=$2
expected_version=$3
binary_relative=$4
destination=$5
[[ -f "$archive" && ! -L "$archive" ]] || fail "archive is not a regular file: $archive"
[[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] || fail 'SHA256 must be 64 lowercase hexadecimal characters'
[[ "$expected_version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || fail 'version must contain numeric dot-separated components'
[[ "$binary_relative" =~ ^[A-Za-z0-9._/-]+$ && "$binary_relative" != /* ]] \
  || fail 'binary path must be a relative path with safe characters'
case "/$binary_relative/" in
  */../*|*/./*) fail 'binary path must not contain dot segments' ;;
esac

archive_digest=$(sha256sum -- "$archive") || fail 'could not hash archive'
archive_digest=${archive_digest%% *}
[[ "$archive_digest" == "$expected_sha256" ]] \
  || fail "archive SHA256 mismatch: expected $expected_sha256, got $archive_digest"
parent=$(dirname -- "$destination")
mkdir -p -- "$parent"
marker=.dinx-verified-archive-sha256
valid_extraction() {
  [[ -d "$destination" && ! -L "$destination" \
    && -f "$destination/$marker" && ! -L "$destination/$marker" \
    && $(<"$destination/$marker") == "$expected_sha256" \
    && -f "$destination/$binary_relative" && -x "$destination/$binary_relative" ]] \
    && [[ $("$destination/$binary_relative" version 2>/dev/null) == "$expected_version" ]]
}
if valid_extraction; then
  printf 'cache-verified-extract: cache-hit version=%s sha256=%s path=%s\n' \
    "$expected_version" "$expected_sha256" "$destination"
  exit 0
fi
if [[ -e "$destination" || -L "$destination" ]]; then
  [[ -d "$destination" && ! -L "$destination" ]] \
    || fail "refusing to replace non-directory extraction cache entry: $destination"
  rm -rf -- "$destination"
fi

temporary=$(mktemp -d "$parent/.extract.XXXXXXXX") || fail 'could not create extraction staging directory'
cleanup() {
  rm -rf -- "$temporary"
}
trap cleanup EXIT
if ! tar -xJf "$archive" --directory "$temporary"; then
  fail "could not extract verified archive: $archive"
fi
mapfile -d '' entries < <(find "$temporary" -mindepth 1 -maxdepth 1 -print0)
[[ ${#entries[@]} -eq 1 && -d "${entries[0]}" && ! -L "${entries[0]}" ]] \
  || fail 'archive must contain exactly one top-level directory'
extracted=${entries[0]}
[[ -f "$extracted/$binary_relative" && ! -L "$extracted/$binary_relative" \
  && -x "$extracted/$binary_relative" ]] \
  || fail "archive is missing executable $binary_relative"
actual_version=$("$extracted/$binary_relative" version 2>/dev/null) \
  || fail "extracted executable failed: $binary_relative"
[[ "$actual_version" == "$expected_version" ]] \
  || fail "extracted tool version mismatch: expected $expected_version, got $actual_version"
printf '%s\n' "$expected_sha256" > "$extracted/$marker"
mv -T -- "$extracted" "$destination" || fail "could not publish extraction cache: $destination"
if [[ -n ${DINX_CACHE_DIRTY_MARKER:-} ]]; then
  mkdir -p -- "$(dirname -- "$DINX_CACHE_DIRTY_MARKER")"
  touch -- "$DINX_CACHE_DIRTY_MARKER"
fi
printf 'cache-verified-extract: extracted version=%s sha256=%s path=%s\n' \
  "$expected_version" "$expected_sha256" "$destination"
