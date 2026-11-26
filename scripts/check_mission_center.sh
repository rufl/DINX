#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
pkg="$root/distro/packages/mission-center/PKGBUILD"
source_env="$root/distro/packages/mission-center/source.env"
wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/missioncenter-dinx"
desktop_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/io.missioncenter.MissionCenter.desktop"
builder="$root/scripts/build-iso-container.sh"
workflow="$root/.github/workflows/p0-iso.yml"
iso_check="$root/scripts/check-iso-content.sh"
fail() { printf 'mission_center_contract: %s\n' "$*" >&2; exit 1; }

for path in "$profile" "$groups" "$pkg" "$source_env" "$builder" "$workflow" "$iso_check" \
  "$wrapper" "$desktop_override"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done
source "$source_env"
[[ "$MISSION_CENTER_VERSION" == 1.2.0 ]] || fail 'Mission Center version changed without a reviewed pin'
for checksum in "$MISSION_CENTER_SOURCE_SHA256" "$MISSION_CENTER_MAGPIE_SOURCE_SHA256" "$MISSION_CENTER_GRAPH_WIDGET_SOURCE_SHA256"; do
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail 'Mission Center source checksum is invalid'
done
for package in mission-center; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
  grep -Fq "        \"$package\"," "$groups" || fail "desktop group is missing $package"
done
grep -Fq 'pkgname=mission-center' "$pkg" || fail 'package name is not mission-center'
grep -Fq 'source.env' "$pkg" || fail 'package does not load source.env'
grep -Fq 'mission-center-v$pkgver.tar.gz::$MISSION_CENTER_SOURCE_URL' "$pkg" || fail 'upstream Mission Center archive is not pinned'
grep -Fq 'gng-$MISSION_CENTER_MAGPIE_COMMIT.tar.gz::$MISSION_CENTER_MAGPIE_SOURCE_URL' "$pkg" || fail 'Magpie submodule archive is not pinned'
grep -Fq 'graph-widget-$MISSION_CENTER_GRAPH_WIDGET_COMMIT.tar.gz::$MISSION_CENTER_GRAPH_WIDGET_SOURCE_URL' "$pkg" || fail 'graph-widget submodule archive is not pinned'
if grep -Eiq '(^|[^[:alnum:]_])(systemd|systemctl|uwsm)([^[:alnum:]_]|$)' "$pkg"; then
  fail 'Mission Center package recipe introduces systemd or uwsm'
fi
grep -Fq 'CFLAGS="${CFLAGS//-flto=auto/}"' "$pkg" \
  || fail 'Mission Center does not remove Arch LTO flags before ring compilation'
grep -Fq 'CXXFLAGS="${CXXFLAGS//-flto=auto/}"' "$pkg" \
  || fail 'Mission Center does not remove C++ LTO flags before ring compilation'
grep -Fq 'build_package mission-center' "$builder" || fail 'ISO builder does not build Mission Center'
grep -Fq 'mission-center-*.pkg.tar.zst' "$builder" || fail 'ISO builder does not install Mission Center before ISO assembly'
[[ -x "$wrapper" ]] || fail 'Mission Center dark wrapper is not executable'
sh -n "$wrapper" || fail 'Mission Center dark wrapper has invalid shell syntax'
grep -Fqx 'export ADW_DEBUG_COLOR_SCHEME=prefer-dark' "$wrapper" \
  || fail 'Mission Center wrapper does not force the libadwaita dark scheme'
grep -Fqx 'Exec=missioncenter-dinx' "$desktop_override" \
  || fail 'Mission Center desktop override does not use the dark wrapper'
grep -Fq 'scripts/check_mission_center.sh' "$workflow" || fail 'workflow does not run the Mission Center contract'
for required in \
  '  usr/bin/missioncenter' \
  '  usr/share/applications/io.missioncenter.MissionCenter.desktop' \
  '  usr/share/metainfo/io.missioncenter.MissionCenter.metainfo.xml' \
  '  usr/share/licenses/mission-center/COPYING'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done
printf 'mission_center_contract version=%s source_pins=3 systemd=false upstream=gitlab base=true\n' "$MISSION_CENTER_VERSION"
