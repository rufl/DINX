#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_env="$root/distro/packages/swayimg/source.env"
pkgbuild="$root/distro/packages/swayimg/PKGBUILD"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
builder="$root/scripts/build-iso-container.sh"

# shellcheck disable=SC1090
source "$source_env"

[[ "$SWAYIMG_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]]
[[ "$SWAYIMG_SOURCE_URL" == https://github.com/artemsen/swayimg/archive/*".tar.gz" ]] \
  || { printf 'swayimg_contract: source URL is not an upstream archive URL\n' >&2; exit 1; }
[[ "$SWAYIMG_SOURCE_URL" == *"${SWAYIMG_VERSION}.tar.gz" ]] \
  || { printf 'swayimg_contract: source URL does not match the pinned version\n' >&2; exit 1; }
[[ "$SWAYIMG_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]]
grep -Fq 'pkgver="$SWAYIMG_VERSION"' "$pkgbuild"
grep -Fq '${SWAYIMG_SOURCE_URL}' "$pkgbuild"
grep -Fq '"$SWAYIMG_SOURCE_SHA256"' "$pkgbuild"
grep -Fq "sha256sums=(\"\$SWAYIMG_SOURCE_SHA256\")" "$pkgbuild"
grep -Fq '    - swayimg' "$profile"
grep -Fq 'build_package swayimg' "$builder"

printf 'swayimg_contract version=%s source_pinned=true checksum_pinned=true profile_entry=true container_builder=true\n' "$SWAYIMG_VERSION"
