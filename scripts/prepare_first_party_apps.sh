#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_env="$repo_root/distro/packages/deetty/source.env"
package_dir="$repo_root/distro/packages/deetty"
source_dir=${1:-"$repo_root/third_party/noctty"}

fail() {
  printf 'prepare_first_party_apps: %s\n' "$*" >&2
  exit 1
}

read_source_value() {
  local key=$1
  sed -n "s/^${key}=//p" "$source_env" | head -n 1
}

[[ -r "$source_env" ]] || fail "missing source contract: $source_env"
[[ -d "$source_dir" ]] || fail "source checkout not found: $source_dir"
command -v git >/dev/null 2>&1 || fail 'git is required'
command -v gzip >/dev/null 2>&1 || fail 'gzip is required'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'

version=$(read_source_value DEETTY_VERSION)
ref=$(read_source_value DEETTY_REF)
expected_sha=$(read_source_value DEETTY_SOURCE_SHA256)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid version: $version"
[[ "$ref" =~ ^[0-9a-f]{40}$ ]] || fail "invalid source ref: $ref"
[[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || fail "invalid source sha256: $expected_sha"

actual_ref=$(git -C "$source_dir" rev-parse HEAD 2>/dev/null) ||
  fail "not a git checkout: $source_dir"
[[ "$actual_ref" == "$ref" ]] ||
  fail "source ref mismatch expected=$ref actual=$actual_ref"
git -C "$source_dir" diff --quiet HEAD -- ||
  fail "source checkout has tracked changes: $source_dir"

archive="$package_dir/noctty-$version.tar.gz"
tmp_archive=$(mktemp "$package_dir/.deetty-source.XXXXXX")
cleanup() {
  [[ -z "$tmp_archive" ]] || rm -f -- "$tmp_archive"
}
trap cleanup EXIT HUP INT TERM

git -C "$source_dir" archive \
  --format=tar \
  --prefix="noctty-$version/" \
  "$ref" | gzip -n >"$tmp_archive"
actual_sha=$(sha256sum "$tmp_archive" | awk '{print $1}')
[[ "$actual_sha" == "$expected_sha" ]] ||
  fail "source sha256 mismatch expected=$expected_sha actual=$actual_sha"
mv -f -- "$tmp_archive" "$archive"
tmp_archive=

printf 'first_party_apps package=deetty source=NOCTTY version=%s ref=%s sha256=%s archive=%s dintor_included=true\n' \
  "$version" "$ref" "$actual_sha" "$archive"
