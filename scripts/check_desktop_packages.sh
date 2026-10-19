#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
iso_check="$root/scripts/check-iso-content.sh"
mimeapps="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"

fail() {
  printf 'desktop_packages_contract: FAIL: %s\n' "$1" >&2
  exit 1
}

for package in sane fwupd flatpak kolourpaint; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done

grep -Fqx '  usr/bin/scanimage' "$iso_check" || fail 'ISO payload is missing scanimage'
grep -Fqx '  usr/bin/fwupdmgr' "$iso_check" || fail 'ISO payload is missing fwupdmgr'
grep -Fqx '  usr/bin/flatpak' "$iso_check" || fail 'ISO payload is missing flatpak'
grep -Fqx '  usr/bin/kolourpaint' "$iso_check" || fail 'ISO payload is missing kolourpaint'
grep -Fqx '  usr/share/flatpak/remotes.d/flathub.flatpakrepo' "$iso_check" || fail 'ISO payload is missing the Flatpak source descriptor'
grep -Fqx '  usr/share/applications/org.kde.kolourpaint.desktop' "$iso_check" || fail 'ISO payload is missing the KolourPaint desktop entry'
grep -Fqx 'image/png=swayimg.desktop;' "$mimeapps" || fail 'Swayimg is no longer the default image viewer'

printf 'desktop_packages_contract sane=true fwupd=true flatpak=true kolourpaint=true image_viewer=swayimg\n'
