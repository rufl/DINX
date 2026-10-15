#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'package_managers_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

for path in \
  distro/packages/topgrade/PKGBUILD \
  distro/packages/topgrade/source.env \
  distro/packages/paru/PKGBUILD \
  distro/packages/paru/source.env \
  distro/packages/shelly/PKGBUILD \
  distro/packages/shelly/source.env; do
  [[ -f "$path" ]] || fail "missing package-management contract file: $path"
done

source distro/packages/topgrade/source.env
source distro/packages/paru/source.env
source distro/packages/shelly/source.env

[[ "$TOPGRADE_VERSION" == 17.12.3 ]] || fail "unexpected topgrade version: $TOPGRADE_VERSION"
[[ "$TOPGRADE_SOURCE_URL" == *"topgrade-v${TOPGRADE_VERSION}-x86_64-unknown-linux-musl.tar.gz" ]] || fail 'topgrade source URL is not pinned to the release'
[[ "$TOPGRADE_SOURCE_B2" == b1e9610c7c0f59a753888c204ffc1980ad7766f5a7c0f98d7c93e87d4ef0d3078fee5df3900a9cafdbdd1c8297b9e77523b353264b7d43583cf1c7360be3f02c ]] || fail 'topgrade source BLAKE2 checksum changed'
grep -Fq "pkgver=${TOPGRADE_VERSION}" distro/packages/topgrade/PKGBUILD || fail 'topgrade PKGBUILD version is not pinned'
grep -Fq "$TOPGRADE_SOURCE_B2" distro/packages/topgrade/PKGBUILD || fail 'topgrade PKGBUILD checksum is not pinned'

grep -Fq "pkgver=${PARU_VERSION}" distro/packages/paru/PKGBUILD || fail 'paru PKGBUILD version is not pinned'
grep -Fq "$PARU_SOURCE_SHA256" distro/packages/paru/PKGBUILD || fail 'paru PKGBUILD checksum is not pinned'
grep -Fq 'Morganamilo/paru/releases/download/v${pkgver}/paru-v${pkgver}-x86_64.tar.zst' distro/packages/paru/PKGBUILD || fail 'paru release source is not pinned'

grep -Fq "pkgver=${SHELLY_VERSION}" distro/packages/shelly/PKGBUILD || fail 'shelly PKGBUILD version is not pinned'
grep -Fq "$SHELLY_SOURCE_SHA256" distro/packages/shelly/PKGBUILD || fail 'shelly PKGBUILD checksum is not pinned'
grep -Fq 'Seafoam-Labs/Shelly-ALPM/releases/download/v${pkgver}/Shelly-ALPM-linux-x64.tar.gz' distro/packages/shelly/PKGBUILD || fail 'shelly release source is not pinned'

grep -Fq '    - topgrade' distro/iso/iso-profiles/dinx/profile.yaml || fail 'topgrade is missing from the DINX payload'
grep -Fq '    - paru' distro/iso/iso-profiles/dinx/profile.yaml || fail 'paru is missing from the DINX payload'
grep -Fq '    - shelly' distro/iso/iso-profiles/dinx/profile.yaml || fail 'shelly is missing from the DINX payload'

grep -Fq 'build_package topgrade' .github/workflows/p0-iso.yml || fail 'CI does not build topgrade'
grep -Fq 'build_package paru' .github/workflows/p0-iso.yml || fail 'CI does not build paru'
grep -Fq 'build_package shelly' .github/workflows/p0-iso.yml || fail 'CI does not build shelly'
printf 'package_managers_contract topgrade=%s paru=%s shelly=%s sources_pinned=true\n' \
  "$TOPGRADE_VERSION" "$PARU_VERSION" "$SHELLY_VERSION"
