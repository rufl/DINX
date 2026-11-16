#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
pkg="$root/distro/packages/eurooffice/PKGBUILD"
source_env="$root/distro/packages/eurooffice/source.env"
launcher="$root/distro/packages/eurooffice/eurooffice"
desktop="$root/distro/packages/eurooffice/eurooffice.desktop"
iso_check="$root/scripts/check-iso-content.sh"
builder="$root/scripts/build-iso-container.sh"
workflow="$root/.github/workflows/p0-iso.yml"
mimeapps="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"

fail() {
  printf 'eurooffice_contract: FAIL: %s\n' "$1" >&2
  exit 1
}

for path in "$profile" "$groups" "$pkg" "$source_env" "$launcher" "$desktop" "$iso_check" "$builder" "$workflow" "$mimeapps"; do
  [[ -r "$path" ]] || fail "missing file: ${path#$root/}"
done
source "$source_env"
[[ "$EUROOFFICE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-alpha$ ]] || fail 'invalid EuroOffice version'
[[ "$EUROOFFICE_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid EuroOffice checksum'
grep -Fqx '    - eurooffice' "$profile" || fail 'profile is missing EuroOffice'
jq -e '.groups.desktop.packages | index("eurooffice") != null' "$groups" >/dev/null \
  || fail 'desktop group is missing EuroOffice'
if grep -Eiq '(^|[[:space:]])onlyoffice([[:space:]]|$)|onlyoffice\.desktop' "$profile" "$groups" "$mimeapps"; then
  fail 'ONLYOFFICE remains selected or registered'
fi
grep -Fq 'pkgname=eurooffice' "$pkg" || fail 'package name is not eurooffice'
grep -Fq 'Euro-Office-Lite_${pkgver}_amd64.deb::$EUROOFFICE_SOURCE_URL' "$pkg" \
  || fail 'EuroOffice source is not pinned'
grep -Fq "depends=('glibc' 'gtk3' 'webkit2gtk-4.1')" "$pkg" \
  || fail 'EuroOffice runtime dependency contract is incomplete'
bash -n "$launcher" || fail 'EuroOffice launcher syntax is invalid'
grep -Fqx 'exec /usr/bin/euro-office-lite "$@"' "$launcher" || fail 'EuroOffice launcher is not argv-safe'
grep -Fqx 'Exec=eurooffice %U' "$desktop" || fail 'EuroOffice desktop launcher is incorrect'
for mime in \
  application/msword \
  application/vnd.openxmlformats-officedocument.wordprocessingml.document \
  application/vnd.oasis.opendocument.text \
  application/rtf \
  application/vnd.ms-excel \
  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet \
  application/vnd.oasis.opendocument.spreadsheet \
  text/csv \
  application/vnd.ms-powerpoint \
  application/vnd.openxmlformats-officedocument.presentationml.presentation \
  application/vnd.oasis.opendocument.presentation \
  application/pdf; do
  grep -Fq "$mime;" "$desktop" || fail "EuroOffice is missing MIME type $mime"
done
for required in \
  '  usr/bin/euro-office-lite' \
  '  usr/bin/eurooffice' \
  '  usr/lib/Euro-Office-Lite/binaries/libkernel.so' \
  '  usr/share/applications/eurooffice.desktop' \
  '  usr/share/licenses/eurooffice/LICENSE'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done
grep -Fq 'build_package eurooffice' "$builder" || fail 'ISO builder does not build EuroOffice'
grep -Fq 'scripts/check_eurooffice.sh' "$workflow" || fail 'workflow does not run the EuroOffice contract'
printf 'eurooffice_contract version=%s lean=true onlyoffice=false pdf=true\n' "$EUROOFFICE_VERSION"
