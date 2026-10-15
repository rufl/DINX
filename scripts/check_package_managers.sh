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
  distro/packages/paru/paru.conf \
  distro/packages/shelly/PKGBUILD \
  distro/packages/shelly/source.env \
  distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/topgrade.toml; do
  [[ -f "$path" ]] || fail "missing package-management contract file: $path"
done

source distro/packages/topgrade/source.env
source distro/packages/paru/source.env
source distro/packages/shelly/source.env

[[ "$TOPGRADE_VERSION" == 17.12.3 ]] || fail "unexpected topgrade version: $TOPGRADE_VERSION"
[[ "$TOPGRADE_SOURCE_URL" == *"topgrade/archive/refs/tags/v${TOPGRADE_VERSION}.tar.gz" ]] || fail 'topgrade source URL is not pinned to the source release'
[[ "$TOPGRADE_SOURCE_B2" == 4a4fe41e6c030a33d44690c603838d2f95ccc09a17a1ed8679f29c6f629a1d95a689f3cafaf533b716732bfb7d2c2e8d84816df8ef65dab445ab09183a623bca ]] || fail 'topgrade source BLAKE2 checksum changed'
grep -Fq "pkgver=${TOPGRADE_VERSION}" distro/packages/topgrade/PKGBUILD || fail 'topgrade PKGBUILD version is not pinned'
grep -Fq "$TOPGRADE_SOURCE_B2" distro/packages/topgrade/PKGBUILD || fail 'topgrade PKGBUILD checksum is not pinned'

[[ "$PARU_SOURCE_URL" == *"Morganamilo/paru/archive/v${PARU_VERSION}.tar.gz" ]] || fail 'paru source URL is not pinned to the source release'
grep -Fq "pkgver=${PARU_VERSION}" distro/packages/paru/PKGBUILD || fail 'paru PKGBUILD version is not pinned'
grep -Fq "$PARU_SOURCE_SHA256" distro/packages/paru/PKGBUILD || fail 'paru source checksum is not pinned'

[[ "$SHELLY_SOURCE_URL" == *"Seafoam-Labs/Shelly-ALPM/releases/download/v${SHELLY_VERSION}/Shelly-ALPM-linux-x64.tar.gz" ]] || fail 'shelly release source is not pinned'
grep -Fq "pkgver=${SHELLY_VERSION}" distro/packages/shelly/PKGBUILD || fail 'shelly PKGBUILD version is not pinned'
grep -Fq "$SHELLY_SOURCE_SHA256" distro/packages/shelly/PKGBUILD || fail 'shelly release source checksum is not pinned'

for package in topgrade paru shelly; do
  if grep -Eiq '(^|[^[:alnum:]_])systemd([^[:alnum:]_]|$)' "distro/packages/$package/PKGBUILD"; then
    fail "$package PKGBUILD contains a systemd dependency or integration"
  fi
done
grep -Fq 'etc/paru.conf' distro/packages/paru/PKGBUILD || fail 'paru Artix pacman configuration is not packaged'
grep -Fq 'pacman' distro/packages/shelly/PKGBUILD || fail 'shelly is not tied to the Artix pacman stack'
grep -Fq 'pacman' distro/packages/paru/PKGBUILD || fail 'paru is not tied to the Artix pacman stack'
grep -Fq 'Do not add Arch Linux repositories' distro/packages/paru/paru.conf || fail 'paru configuration does not enforce Artix repositories'
grep -Fq 'arch_package_manager = "pacman"' distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/topgrade.toml || fail 'topgrade is not configured for Artix pacman'

grep -Fq '    - topgrade' distro/iso/iso-profiles/dinx/profile.yaml || fail 'topgrade is missing from the DINX payload'
grep -Fq '    - paru' distro/iso/iso-profiles/dinx/profile.yaml || fail 'paru is missing from the DINX payload'
grep -Fq '    - shelly' distro/iso/iso-profiles/dinx/profile.yaml || fail 'shelly is missing from the DINX payload'

grep -Fq 'build_package topgrade' .github/workflows/p0-iso.yml || fail 'CI does not build topgrade'
grep -Fq 'build_package paru' .github/workflows/p0-iso.yml || fail 'CI does not build paru'
grep -Fq 'build_package shelly' .github/workflows/p0-iso.yml || fail 'CI does not build shelly'
printf 'package_managers_contract topgrade=%s paru=%s shelly=%s artix_native_sources=true systemd_dependencies=false\n' \
  "$TOPGRADE_VERSION" "$PARU_VERSION" "$SHELLY_VERSION"
