#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'bc250_control_center_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

for path in \
  distro/packages/bc250-control-center/PKGBUILD \
  distro/packages/bc250-control-center/source.env \
  distro/iso/iso-profiles/dinx/profile.yaml \
  distro/iso/iso-profiles/dinx/root-overlay/etc/mango/dinx.conf \
  distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/config.toml; do
  [[ -f "$path" ]] || fail "missing contract file: $path"
done

source distro/packages/bc250-control-center/source.env
[[ "$BC250_CONTROL_CENTER_VERSION" == 1.21.1 ]] || fail "unexpected version: $BC250_CONTROL_CENTER_VERSION"
[[ "$BC250_CONTROL_CENTER_SOURCE_URL" == "https://github.com/movacx/bc250-control-center/archive/refs/tags/v${BC250_CONTROL_CENTER_VERSION}.tar.gz" ]] || fail 'source URL is not pinned to the release tag'
grep -Fq "pkgver=${BC250_CONTROL_CENTER_VERSION}" distro/packages/bc250-control-center/PKGBUILD || fail 'PKGBUILD version is not pinned'
grep -Fq "$BC250_CONTROL_CENTER_SOURCE_SHA256" distro/packages/bc250-control-center/PKGBUILD || fail 'source SHA-256 is not pinned'
grep -Fq "license=('MIT')" distro/packages/bc250-control-center/PKGBUILD || fail 'MIT license is missing'
for dependency in python-pyqt6 python-psutil qt6-svg polkit pciutils kmod; do
  grep -Fq "  '$dependency'" distro/packages/bc250-control-center/PKGBUILD || fail "runtime dependency is missing: $dependency"
done
if grep -Eiq "^[[:space:]]*['\"]systemd([^-[:alnum:]_]|$)" distro/packages/bc250-control-center/PKGBUILD; then
  fail 'systemd is a package dependency'
fi
grep -Fq 'rm -rf "$pkgdir/usr/lib/systemd"' distro/packages/bc250-control-center/PKGBUILD || fail 'upstream systemd payload is not removed'
if grep -Eq '^install=' distro/packages/bc250-control-center/PKGBUILD; then
  fail 'package install hook could invoke an unsupported init manager'
fi

grep -Fq '    - bc250-control-center' distro/iso/iso-profiles/dinx/profile.yaml || fail 'package is missing from the DINX rootfs'
grep -Fq '    - python-pyqt6' distro/iso/iso-profiles/dinx/profile.yaml || fail 'PyQt6 runtime is missing from the DINX rootfs'
grep -Fq '    - python-psutil' distro/iso/iso-profiles/dinx/profile.yaml || fail 'psutil runtime is missing from the DINX rootfs'
grep -Fq '    - qt6-svg' distro/iso/iso-profiles/dinx/profile.yaml || fail 'Qt SVG runtime is missing from the DINX rootfs'
grep -Fq 'build_package bc250-control-center' .github/workflows/p0-iso.yml || fail 'CI does not build BC250 Control Center'
grep -Fq 'exec_once=bc250-control-centerd' distro/iso/iso-profiles/dinx/root-overlay/etc/mango/dinx.conf || fail 'session daemon autostart is missing'
grep -Fq 'io.github.movacx.bc250-control-center' distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/config.toml || fail 'Noctalia dock launcher is missing'

printf 'bc250_control_center_contract version=%s python=>=3.12 pyqt6=true daemon=session_autostart systemd=false source_sha256=%s\n' \
  "$BC250_CONTROL_CENTER_VERSION" "$BC250_CONTROL_CENTER_SOURCE_SHA256"
