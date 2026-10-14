#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_env="$repo_root/distro/packages/noctty/source.env"
pkgbuild="$repo_root/distro/packages/noctty/PKGBUILD"
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"

fail() {
  printf 'check_first_party_apps: %s\n' "$*" >&2
  exit 1
}

[[ -r "$source_env" ]] || fail "missing $source_env"
[[ -r "$pkgbuild" ]] || fail "missing $pkgbuild"
[[ -r "$profile" ]] || fail "missing $profile"

read_value() {
  local key=$1
  sed -n "s/^${key}=//p" "$source_env" | head -n 1
}

repository=$(read_value NOCTTY_REPOSITORY)
ref=$(read_value NOCTTY_REF)
version=$(read_value NOCTTY_VERSION)
source_sha=$(read_value NOCTTY_SOURCE_SHA256)
[[ "$repository" == https://github.com/rufl/NOCTTY.git ]] || fail "unexpected repository: $repository"
[[ "$ref" =~ ^[0-9a-f]{40}$ ]] || fail "invalid source ref: $ref"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid version: $version"
[[ "$source_sha" =~ ^[0-9a-f]{64}$ ]] || fail "invalid source sha256: $source_sha"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'
command -v tar >/dev/null 2>&1 || fail 'tar is required'

archive="$repo_root/distro/packages/noctty/noctty-$version.tar.gz"
[[ -r "$archive" ]] || fail "missing source archive: $archive"
actual_sha=$(sha256sum "$archive" | awk '{print $1}')
[[ "$actual_sha" == "$source_sha" ]] ||
  fail "source archive sha256 mismatch expected=$source_sha actual=$actual_sha"
tar -tzf "$archive" | grep -F 'noctty-'"$version"'/build.zig' >/dev/null ||
  fail 'source archive does not contain build.zig'
tar -tzf "$archive" | grep -F 'noctty-'"$version"'/src/main.zig' >/dev/null ||
  fail 'source archive does not contain src/main.zig'

grep -Fqx 'pkgname=noctty' "$pkgbuild" || fail 'PKGBUILD package name is not noctty'
grep -Fq "provides=('nocted' 'terminal-emulator')" "$pkgbuild" || fail 'PKGBUILD does not provide nocted'
grep -Fq "'gtksourceview4'" "$pkgbuild" || fail 'NoctEd runtime dependency is missing'
grep -Fq '  - noctty' "$profile" || fail 'DINX profile does not install noctty'

printf 'first_party_apps_contract repository=%s ref=%s version=%s noctty=true nocted=true source_pinned=true archive_verified=true profile_entry=true\n' \
  "$repository" "$ref" "$version"
