#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
pkg="$root/distro/packages/tuxmanager/PKGBUILD"
source_env="$root/distro/packages/tuxmanager/source.env"
builder="$root/scripts/build-iso-container.sh"
workflow="$root/.github/workflows/p0-iso.yml"
iso_check="$root/scripts/check-iso-content.sh"
fail() { printf 'tuxmanager_contract: %s\n' "$*" >&2; exit 1; }

for path in "$profile" "$groups" "$pkg" "$source_env" "$builder" "$workflow" "$iso_check"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done
source "$source_env"
[[ "$TUXMANAGER_VERSION" == 1.1.0 ]] || fail 'TuxManager version changed without a reviewed pin'
[[ "$TUXMANAGER_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'TuxManager source checksum is invalid'
grep -Fqx '    - tuxmanager' "$profile" || fail 'profile is missing tuxmanager'
grep -Fq '                "tuxmanager",' "$groups" || fail 'desktop group is missing tuxmanager'
grep -Fq 'pkgname=tuxmanager' "$pkg" || fail 'package name is not tuxmanager'
grep -Fq 'source.env' "$pkg" || fail 'package does not load source.env'
grep -Fq '$TUXMANAGER_SOURCE_URL' "$pkg" || fail 'upstream TuxManager archive is not pinned'
grep -Fq 'qmake6 src/TuxManager.pro' "$pkg" || fail 'package does not use the Qt6 project file'
grep -Fq 'build_package tuxmanager' "$builder" || fail 'ISO builder does not build TuxManager'
grep -Fq 'tuxmanager-*.pkg.tar.zst' "$builder" || fail 'ISO builder does not install TuxManager before ISO assembly'
grep -Fq 'scripts/check_tuxmanager.sh' "$workflow" || fail 'workflow does not run the TuxManager contract'
for required in \
  '  usr/bin/tux-manager' \
  '  usr/share/icons/hicolor/scalable/apps/tux_manager_icon.svg' \
  '  usr/share/applications/io.github.benapetr.TuxManager.desktop' \
  '  usr/share/metainfo/io.github.benapetr.TuxManager.metainfo.xml'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done
printf 'tuxmanager_contract version=%s source_sha256=true upstream=github base=true\n' "$TUXMANAGER_VERSION"
