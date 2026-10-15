#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_env="$root/distro/packages/swayimg/source.env"
pkgbuild="$root/distro/packages/swayimg/PKGBUILD"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
workflow="$root/.github/workflows/p0-iso.yml"

# shellcheck disable=SC1090
source "$source_env"

expected_url="https://github.com/artemsen/swayimg/archive/v${SWAYIMG_VERSION}.tar.gz"

[[ "$SWAYIMG_SOURCE_URL" == "$expected_url" ]]
[[ "$SWAYIMG_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]]
grep -Fq "pkgname=swayimg" "$pkgbuild"
grep -Fq "pkgver=${SWAYIMG_VERSION}" "$pkgbuild"
grep -Fq 'https://github.com/artemsen/swayimg/archive/v${pkgver}.tar.gz' "$pkgbuild"
grep -Fq "$SWAYIMG_SOURCE_SHA256" "$pkgbuild"
grep -Fq "sha256sums=('${SWAYIMG_SOURCE_SHA256}')" "$pkgbuild"
grep -Fq '    - swayimg' "$profile"
grep -Fq 'build_package swayimg' "$workflow"

printf 'swayimg_contract version=%s source_pinned=true checksum_pinned=true profile_entry=true workflow_build=true\n' "$SWAYIMG_VERSION"
