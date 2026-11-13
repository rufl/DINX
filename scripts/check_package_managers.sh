#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'package_managers_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

for path in \
  distro/packages/paru/PKGBUILD \
  distro/packages/paru/source.env \
  distro/packages/paru/paru.conf \
  distro/packages/shelly/PKGBUILD \
  distro/packages/shelly/source.env; do
  [[ -f "$path" ]] || fail "missing package-management contract file: $path"
done

source distro/packages/paru/source.env
source distro/packages/shelly/source.env

[[ "$PARU_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid paru version: $PARU_VERSION"
[[ "$PARU_SOURCE_URL" == *"Morganamilo/paru/archive/"*"${PARU_VERSION}.tar.gz" ]] \
  || fail 'paru source URL is not pinned to the source release'
grep -Fq 'pkgver="$PARU_VERSION"' distro/packages/paru/PKGBUILD \
  || fail 'paru PKGBUILD version is not wired to source.env'
grep -Fq '"$PARU_SOURCE_SHA256"' distro/packages/paru/PKGBUILD \
  || fail 'paru PKGBUILD checksum is not wired to source.env'
grep -Fq 'cargo update -p openssl --precise 0.10.78' distro/packages/paru/PKGBUILD \
  || fail 'paru does not pin Rust OpenSSL bindings compatible with Artix OpenSSL 4.1'
grep -Fq 'cargo update -p openssl-sys --precise 0.9.118' distro/packages/paru/PKGBUILD \
  || fail 'paru does not pin an openssl-sys release compatible with Artix OpenSSL 4.1'

[[ "$SHELLY_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Shelly version: $SHELLY_VERSION"
[[ "$SHELLY_SOURCE_URL" == *"Seafoam-Labs/Shelly-ALPM/releases/download/"*"/Shelly-ALPM-linux-x64.tar.gz" ]] \
  || fail 'Shelly release source URL is malformed'
grep -Fq 'pkgver="$SHELLY_VERSION"' distro/packages/shelly/PKGBUILD \
  || fail 'Shelly PKGBUILD version is not wired to source.env'
grep -Fq '"$SHELLY_SOURCE_SHA256"' distro/packages/shelly/PKGBUILD \
  || fail 'Shelly release source checksum is not wired to source.env'
aur_sources=(
  'shellybuild.conf'
  'com.shellyorg.shelly.desktop'
  'com.shellyorg.shelly-notifications.desktop'
  'shelly-flatpak-integrate'
)
shelly_pkgbuild=distro/packages/shelly/PKGBUILD
shelly_aur_revision=f89d773125357baaa1d2fae715286ce9e00e2cb4
grep -Fq "_aur_revision='${shelly_aur_revision}'" "$shelly_pkgbuild" || fail 'shelly AUR sources are not pinned to the verified revision'
resolved_shelly_sources=$(bash -c 'startdir=$(dirname "$1"); source "$1"; printf "%s\n" "${source[@]}"' _ "$shelly_pkgbuild")
for source_file in "${aur_sources[@]}"; do
  grep -Fq "${source_file}?h=${shelly_aur_revision}" <<<"$resolved_shelly_sources" || fail "shelly source is not pinned to the verified AUR revision: $source_file"
done

for package in paru shelly; do
  if grep -Eiq '(^|[^[:alnum:]_])systemd([^[:alnum:]_]|$)' "distro/packages/$package/PKGBUILD"; then
    fail "$package PKGBUILD contains a systemd dependency or integration"
  fi
done
grep -Fq 'etc/paru.conf' distro/packages/paru/PKGBUILD || fail 'paru Artix pacman configuration is not packaged'
grep -Fq 'pacman' distro/packages/shelly/PKGBUILD || fail 'shelly is not tied to the Artix pacman stack'
grep -Fq 'pacman' distro/packages/paru/PKGBUILD || fail 'paru is not tied to the Artix pacman stack'
grep -Fq 'Do not add Arch Linux repositories' distro/packages/paru/paru.conf || fail 'paru configuration does not enforce Artix repositories'

grep -Fq '    - paru' distro/iso/iso-profiles/dinx/profile.yaml || fail 'paru is missing from the DINX payload'
grep -Fq '    - shelly' distro/iso/iso-profiles/dinx/profile.yaml || fail 'shelly is missing from the DINX payload'

builder=scripts/build-iso-container.sh
grep -Fq 'build_package paru' "$builder" || fail 'ISO builder does not build paru'
grep -Fq 'build_package shelly' "$builder" || fail 'ISO builder does not build shelly'
printf 'package_managers_contract paru=%s shelly=%s artix_policy=true pinned_payload=true systemd_dependencies=false\n' \
  "$PARU_VERSION" "$SHELLY_VERSION"
