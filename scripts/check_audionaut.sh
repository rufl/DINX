#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
feature_groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
iso_packages=$(jq -er '[.groups[] | select(.iso == true) | .packages[]] | .[]' "$feature_groups")
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
# Keep validating the optional package recipe without making it an ISO input.
if grep -Fqx '    - audionaut' "$profile" \
  || grep -Fqx audionaut <<<"$iso_packages"; then
  fail 'Audionaut is disabled for the NEXT ISO but remains selected'
fi
if grep -Eq '^[[:space:]-]*transit([",]|$)' "$profile" || grep -Fqx transit <<<"$iso_packages"; then
  fail 'Transit remains selected in the DINX profile'
fi
grep -Fq 'pkgver="$AUDIONAUT_VERSION"' "$recipe" || fail 'Audionaut package version is not wired to source.env'
grep -Fq '${AUDIONAUT_SOURCE_URL}' "$recipe" || fail 'Audionaut source URL is not wired to source.env'
grep -Fq '"$AUDIONAUT_SOURCE_SHA256"' "$recipe" || fail 'Audionaut source checksum is not wired to source.env'
grep -Fq '"$AUDIONAUT_LICENSE_SHA256"' "$recipe" || fail 'Audionaut license checksum is not wired to source.env'
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
  if grep -Fqx "$path" "$iso_check"; then
    fail "disabled NEXT Audionaut path remains mandatory in the ISO payload: ${path#  }"
  fi
done
printf 'audionaut_contract: PASS version=%s iso=false optional_recipe=true transit=false\n' "$AUDIONAUT_VERSION"
