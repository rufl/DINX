#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'cyan_skillfish_contract: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

for path in \
  distro/packages/cyan-skillfish-governor-smu/PKGBUILD \
  distro/packages/cyan-skillfish-governor-smu/source.env \
  distro/packages/cyan-skillfish-governor-smu-dinit/PKGBUILD \
  distro/packages/cyan-skillfish-governor-smu-dinit/cyan-skillfish-governor-smu \
  distro/packages/cyan-skillfish-governor-smu-dinit/dinx-cyan-skillfish-governor; do
  [[ -f "$path" ]] || fail "missing contract file: $path"
done

source distro/packages/cyan-skillfish-governor-smu/source.env
[[ "$CYAN_SKILLFISH_GOVERNOR_VERSION" == 0.4.14 ]] || fail 'unexpected governor version'
[[ "$CYAN_SKILLFISH_GOVERNOR_SOURCE_URL" == *"filippor/cyan-skillfish-governor/archive/refs/tags/v${CYAN_SKILLFISH_GOVERNOR_VERSION}.tar.gz" ]] || fail 'governor source URL is not pinned'
grep -Fq "pkgver=${CYAN_SKILLFISH_GOVERNOR_VERSION}" distro/packages/cyan-skillfish-governor-smu/PKGBUILD || fail 'governor version is not pinned'
grep -Fq "$CYAN_SKILLFISH_GOVERNOR_SOURCE_B2" distro/packages/cyan-skillfish-governor-smu/PKGBUILD || fail 'governor checksum is not pinned'

for path in \
  distro/packages/cyan-skillfish-governor-smu/PKGBUILD \
  distro/packages/cyan-skillfish-governor-smu-dinit/PKGBUILD \
  distro/packages/cyan-skillfish-governor-smu-dinit/cyan-skillfish-governor-smu \
  distro/packages/cyan-skillfish-governor-smu-dinit/dinx-cyan-skillfish-governor; do
  if grep -Eiq 'systemd|systemctl' "$path"; then
    fail "systemd integration found in $path"
  fi
done

grep -Fq "depends=('libdrm')" distro/packages/cyan-skillfish-governor-smu/PKGBUILD || fail 'governor is not limited to libdrm runtime dependencies'
grep -Fq 'type               = process' distro/packages/cyan-skillfish-governor-smu-dinit/cyan-skillfish-governor-smu || fail 'governor dinit service is not a process service'
grep -Fq 'restart            = false' distro/packages/cyan-skillfish-governor-smu-dinit/cyan-skillfish-governor-smu || fail 'non-BC250 detection would restart forever'
grep -Fq 'depends-on         = dbus' distro/packages/cyan-skillfish-governor-smu-dinit/cyan-skillfish-governor-smu || fail 'governor does not wait for D-Bus'
grep -Fq '0x1002' distro/packages/cyan-skillfish-governor-smu-dinit/dinx-cyan-skillfish-governor || fail 'AMD vendor detection is missing'
grep -Fq '0x13fe' distro/packages/cyan-skillfish-governor-smu-dinit/dinx-cyan-skillfish-governor || fail 'BC-250 PCI ID detection is missing'
grep -Fq '/etc/cyan-skillfish-governor-smu/config.toml' distro/packages/cyan-skillfish-governor-smu-dinit/dinx-cyan-skillfish-governor || fail 'governor config path is missing'
grep -Fq 'ln -s ../cyan-skillfish-governor-smu' distro/packages/cyan-skillfish-governor-smu-dinit/PKGBUILD || fail 'governor package does not enable its dinit service'

grep -Fq '    - linux-firmware-amdgpu' distro/iso/iso-profiles/dinx/profile.yaml || fail 'AMDGPU firmware is missing from the payload'
grep -Fq '    - vulkan-radeon' distro/iso/iso-profiles/dinx/profile.yaml || fail 'RADV is missing from the payload'
grep -Fq '    - vulkan-tools' distro/iso/iso-profiles/dinx/profile.yaml || fail 'Vulkan diagnostics are missing from the payload'
for package in cyan-skillfish-governor-smu cyan-skillfish-governor-smu-dinit; do
  if grep -Eq "^[[:space:]]+- ${package}([[:space:]]|$)" distro/iso/iso-profiles/dinx/profile.yaml; then
    fail "BC-250 governor package must stay out of the generic ISO: $package"
  fi
done
grep -Fq 'build_package cyan-skillfish-governor-smu' .github/workflows/p0-iso.yml || fail 'CI does not build the governor'
grep -Fq 'build_package cyan-skillfish-governor-smu-dinit' .github/workflows/p0-iso.yml || fail 'CI does not build dinit governor integration'
grep -Fq '                rust' .github/workflows/p0-iso.yml || fail 'CI does not install Rust for source builds'

printf 'cyan_skillfish_contract pci=1002:13fe firmware=amdgpu vulkan=radv governor=%s iso=false signed_repository=true dinit=true systemd=false\n' \
  "$CYAN_SKILLFISH_GOVERNOR_VERSION"
