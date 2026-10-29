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
  distro/packages/pearl/PKGBUILD \
  distro/iso/iso-profiles/dinx/profile.yaml \
  distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor; do
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

if grep -Eq '^[[:space:]]+- (bc250-control-center|cyan-skillfish-governor-smu(-dinit)?)([[:space:]]|$)' distro/iso/iso-profiles/dinx/profile.yaml; then
  fail 'BC-250 packages must stay out of the generic live and installed roots'
fi
jq -e '
  .groups.hardware.iso == false and
  .groups.hardware.external == true and
  (.groups.hardware.packages | index("bc250-control-center") != null) and
  (.groups.hardware.packages | index("cyan-skillfish-governor-smu") != null) and
  (.groups.hardware.packages | index("cyan-skillfish-governor-smu-dinit") != null)
' distro/iso/iso-profiles/dinx/feature-groups.json >/dev/null \
  || fail 'BC-250 packages must remain in the optional signed repository group'
grep -Fq '    - pearl' distro/iso/iso-profiles/dinx/profile.yaml || fail 'Pearl shell is missing from the DINX rootfs'
if grep -Fq '    - python-pyqt6' distro/iso/iso-profiles/dinx/profile.yaml; then
  fail 'BC250-only PyQt6 runtime must not be explicitly installed in the base profile'
fi
if grep -Fq '    - qt6-svg' distro/iso/iso-profiles/dinx/profile.yaml; then
  fail 'BC250-only Qt SVG runtime must not be explicitly installed in the base profile'
fi
for package in bc250-control-center cyan-skillfish-governor-smu cyan-skillfish-governor-smu-dinit; do
  grep -Fq "build_package $package" .github/workflows/p0-iso.yml \
    || fail "CI does not build the optional signed package: $package"
done
grep -Fq 'start_optional bc250 bc250-control-centerd' distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor \
  || fail 'session daemon is not supervised when installed on detected hardware'

printf 'bc250_control_center_contract version=%s python=>=3.12 pyqt6=true iso=false signed_repository=true hardware_gate=pci-1002:13fe systemd=false source_sha256=%s\n' \
  "$BC250_CONTROL_CENTER_VERSION" "$BC250_CONTROL_CENTER_SOURCE_SHA256"
