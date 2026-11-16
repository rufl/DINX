#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
feature_groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
recipe="$root/distro/packages/audionaut/PKGBUILD"
source_file="$root/distro/packages/audionaut/source.env"
launcher="$root/distro/packages/audionaut/audionaut"
desktop="$root/distro/packages/audionaut/audionaut.desktop"
iso_check="$root/scripts/check-iso-content.sh"

fail() {
  printf 'audionaut_contract: FAIL: %s\n' "$1" >&2
  exit 1
}

source "$source_file"
[[ "$AUDIONAUT_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Audionaut version: $AUDIONAUT_VERSION"
[[ "$AUDIONAUT_SOURCE_URL" == "https://github.com/kvoltmer/Audionaut/releases/download/v${AUDIONAUT_VERSION}/Audionaut-${AUDIONAUT_VERSION}-x86_64.AppImage" ]] \
  || fail 'Audionaut source URL does not match its release pin'
for checksum in "$AUDIONAUT_SOURCE_SHA256" "$AUDIONAUT_LICENSE_SHA256"; do
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail 'Audionaut checksum is invalid'
done
grep -Fqx '    - audionaut' "$profile" || fail 'profile is missing audionaut'
grep -Fqx '        "audionaut",' "$feature_groups" || fail 'desktop feature group is missing audionaut'
if grep -Eq '^[[:space:]-]*transit([",]|$)' "$profile" || grep -Fq '"transit"' "$feature_groups"; then
  fail 'Transit remains selected in the DINX profile'
fi
grep -Fq 'pkgver="$AUDIONAUT_VERSION"' "$recipe" || fail 'Audionaut package version is not wired to source.env'
grep -Fq '${AUDIONAUT_SOURCE_URL}' "$recipe" || fail 'Audionaut source URL is not wired to source.env'
grep -Fq '"$AUDIONAUT_SOURCE_SHA256"' "$recipe" || fail 'Audionaut source checksum is not wired to source.env'
grep -Fq '"$AUDIONAUT_LICENSE_SHA256"' "$recipe" || fail 'Audionaut license checksum is not wired to source.env'
grep -Fq 'build_package audionaut' "$root/scripts/build-iso-container.sh" || fail 'ISO builder does not build Audionaut'
grep -Fq "'build_package audionaut'" "$root/scripts/check_dinx_package_provenance.sh" || fail 'package provenance contract omits Audionaut'
[[ -x "$launcher" ]] || fail 'Audionaut launcher is missing or not executable'
sh -n "$launcher" || fail 'Audionaut launcher has invalid shell syntax'
grep -Fqx 'exec /opt/audionaut/Audionaut.AppImage --appimage-extract-and-run "$@"' "$launcher" \
  || fail 'Audionaut launcher does not run the packaged AppImage without FUSE'
grep -Fqx '[Desktop Entry]' "$desktop" || fail 'Audionaut desktop launcher has no entry header'
grep -Fqx 'Name=Audionaut' "$desktop" || fail 'Audionaut desktop name is missing'
grep -Fqx 'Name[pt_BR]=Audionaut' "$desktop" || fail 'Audionaut Portuguese desktop name is missing'
grep -Fqx 'TryExec=audionaut' "$desktop" || fail 'Audionaut desktop prerequisite is incorrect'
grep -Fqx 'Exec=audionaut %F' "$desktop" || fail 'Audionaut desktop command is incorrect'
if grep -Eq '^(Hidden|NoDisplay)=true$' "$desktop"; then
  fail 'Audionaut desktop entry is hidden'
fi
for path in \
  '  usr/bin/audionaut' \
  '  opt/audionaut/Audionaut.AppImage' \
  '  usr/share/applications/audionaut.desktop' \
  '  usr/share/licenses/audionaut/LICENSE.md'; do
  grep -Fqx "$path" "$iso_check" || fail "ISO payload is missing Audionaut path: ${path#  }"
done
printf 'audionaut_contract: PASS version=%s transit=false\n' "$AUDIONAUT_VERSION"
