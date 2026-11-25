#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'package_managers_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

# paru is the AUR helper (CLI, used by DINXPanel's read-only upgrade report);
# octopi is the interactive pacman/AUR front-end. Shelly was retired together
# with the Seafoam-Labs Pearl monorepo and must not silently return.
for path in \
  distro/packages/paru/PKGBUILD \
  distro/packages/paru/source.env \
  distro/packages/paru/paru.conf \
  distro/packages/octopi/PKGBUILD \
  distro/packages/octopi/source.env; do
  [[ -f "$path" ]] || fail "missing package-management contract file: $path"
done

source distro/packages/paru/source.env
source distro/packages/octopi/source.env

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

[[ "$OCTOPI_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Octopi version: $OCTOPI_VERSION"
[[ "$OCTOPI_SOURCE_URL" == *"aarnt/octopi/archive/refs/tags/v"*"${OCTOPI_VERSION}.tar.gz" ]] \
  || fail 'Octopi source URL is not pinned to the tagged upstream archive'
grep -Fq 'pkgver="$OCTOPI_VERSION"' distro/packages/octopi/PKGBUILD \
  || fail 'Octopi PKGBUILD version is not wired to source.env'
grep -Fq '"$OCTOPI_SOURCE_SHA256"' distro/packages/octopi/PKGBUILD \
  || fail 'Octopi PKGBUILD checksum is not wired to source.env'
# DINX ships sudo for general use, but Octopi must still elevate through pkexec/polkit like
# the installer and GParted, never through qt-sudo's su/sudo/doas backends.
octopi_patch=$(ls distro/packages/octopi/*.patch 2>/dev/null | head -1)
[[ -n "$octopi_patch" ]] || fail 'Octopi has no pkexec elevation patch'
grep -Fq 'pkexec' "$octopi_patch" \
  || fail 'Octopi patch does not route elevation through pkexec'
if grep -Eq '\b(qt-sudo|ctn_QTSUDO)\b' distro/packages/octopi/PKGBUILD; then
  fail 'Octopi recipe still depends on qt-sudo instead of polkit'
fi
grep -Fq 'octopi-pkexec' distro/packages/octopi/PKGBUILD \
  || fail 'Octopi PKGBUILD does not apply the pkexec elevation patch'

for package in paru octopi; do
  if grep -Eiq '(^|[^[:alnum:]_])systemd([^[:alnum:]_]|$)' "distro/packages/$package/PKGBUILD"; then
    fail "$package PKGBUILD contains a systemd dependency or integration"
  fi
done
grep -Fq 'etc/paru.conf' distro/packages/paru/PKGBUILD || fail 'paru Artix pacman configuration is not packaged'
grep -Fq 'pacman' distro/packages/octopi/PKGBUILD || fail 'octopi is not tied to the Artix pacman stack'
grep -Fq 'pacman' distro/packages/paru/PKGBUILD || fail 'paru is not tied to the Artix pacman stack'
grep -Fq 'Do not add Arch Linux repositories' distro/packages/paru/paru.conf || fail 'paru configuration does not enforce Artix repositories'

grep -Fq '    - paru' distro/iso/iso-profiles/dinx/profile.yaml || fail 'paru is missing from the DINX payload'
grep -Fq '    - octopi' distro/iso/iso-profiles/dinx/profile.yaml || fail 'octopi is missing from the DINX payload'
grep -Fq '    - pacman-contrib' distro/iso/iso-profiles/dinx/profile.yaml || fail 'pacman-contrib (checkupdates) is missing from the DINX payload'
for retired in shelly seafoam-settings; do
  if grep -Fqx "    - $retired" distro/iso/iso-profiles/dinx/profile.yaml; then
    fail "retired package-manager component remains in the profile: $retired"
  fi
done

builder=scripts/build-iso-container.sh
grep -Fq 'build_package paru' "$builder" || fail 'ISO builder does not build paru'
grep -Fq 'build_package octopi' "$builder" || fail 'ISO builder does not build octopi'
printf 'package_managers_contract paru=%s octopi=%s elevation=pkexec artix_policy=true pinned_payload=true systemd_dependencies=false shelly_removed=true\n' \
  "$PARU_VERSION" "$OCTOPI_VERSION"
