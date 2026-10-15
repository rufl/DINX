#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_env="$repo_root/distro/packages/palemoon/source.env"
pkgbuild="$repo_root/distro/packages/palemoon/PKGBUILD"
desktop="$repo_root/distro/packages/palemoon/palemoon.desktop"
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"

fail() {
  printf 'check_palemoon: %s\n' "$*" >&2
  exit 1
}

[[ -r "$source_env" ]] || fail "missing $source_env"
[[ -r "$pkgbuild" ]] || fail "missing $pkgbuild"
[[ -r "$desktop" ]] || fail "missing $desktop"
[[ -r "$profile" ]] || fail "missing $profile"

read_value() {
  local key=$1
  sed -n "s/^${key}=//p" "$source_env" | head -n 1
}

version=$(read_value PALEMOON_VERSION)
source_url=$(read_value PALEMOON_SOURCE_URL)
source_sha=$(read_value PALEMOON_SOURCE_SHA256)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid version: $version"
[[ "$source_url" == https://rm-us.palemoon.org/release/palemoon-*.tar.xz ]] || fail "unexpected source URL: $source_url"
[[ "$source_sha" =~ ^[0-9a-f]{64}$ ]] || fail "invalid source sha256: $source_sha"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'

expected_source="${source_url}"
grep -Fqx "pkgname=palemoon" "$pkgbuild" || fail 'PKGBUILD package name is not palemoon'
grep -Fqx "pkgver=${version}" "$pkgbuild" || fail "PKGBUILD version is not ${version}"
grep -Fq "$expected_source" "$pkgbuild" || fail 'PKGBUILD source URL is not pinned'
grep -Fq "$source_sha" "$pkgbuild" || fail 'PKGBUILD source SHA-256 is not pinned'
grep -Fqx 'Exec=palemoon %u' "$desktop" || fail 'Pale Moon desktop command is incorrect'
grep -Fqx 'TryExec=palemoon' "$desktop" || fail 'Pale Moon desktop TryExec is missing'
grep -Fqx '    - palemoon' "$profile" || fail 'DINX profile does not install palemoon'
grep -Fqx '    - ffmpeg' "$profile" || fail 'DINX profile does not install ffmpeg for Pale Moon media'

printf 'palemoon_contract version=%s source_pinned=true checksum_pinned=true desktop=true profile_entry=true ffmpeg=true\n' \
  "$version"
