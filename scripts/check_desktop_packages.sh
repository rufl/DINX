#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
feature_groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
iso_check="$root/scripts/check-iso-content.sh"
mimeapps="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"
file_roller_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/org.gnome.FileRoller.desktop"
file_roller_mime_cache="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/mimeinfo.cache"
bluetooth_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-bluetooth-manager"
qps_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/qps.desktop"
local_apps="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications"
calamares_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/calamares.desktop"
dinx_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-installer.desktop"
desktop_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/Desktop/Install DINX.desktop"
desktop_approval="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-approve-desktop-launcher"
display_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/network.cycles.wdisplays.desktop"
live_policy="$root/distro/iso/iso-profiles/dinx/live-overlay/etc/polkit-1/rules.d/00-dinx-live-passwordless.rules"
gparted_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/gparted"
firewall_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/firewall-config"
haruna_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/haruna"
haruna_scheme="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/color-schemes/DINXDark.colors"

fail() {
  printf 'desktop_packages_contract: FAIL: %s\n' "$1" >&2
  exit 1
}
[[ -x "$bluetooth_helper" ]] || fail 'DINX Bluetooth launcher is missing or not executable'
sh -n "$bluetooth_helper" || fail 'DINX Bluetooth launcher has invalid shell syntax'
grep -Fqx 'Name=Display Settings' "$display_launcher" || fail 'Display launcher English name is incorrect'
grep -Fqx 'Exec=dinx-wdisplays' "$display_launcher" || fail 'Display launcher does not use the persistence wrapper'

for package in firewalld firewall-config file-roller galculator gapless gparted haruna sane fwupd flatpak paintfe krita inkscape godot pixelorama patchy blockbench phyto pori shikane udisks2 udisks2-btrfs wdisplays transit zenkai firefox papirus-icon-theme; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done
for package in qogir-icon-theme breeze-icons breeze breeze-cursors qqc2-breeze-style plasma-integration plasma-workspace xdg-desktop-portal-kde zathura zathura-pdf-mupdf libmupdf; do
  if grep -Fqx "    - $package" "$profile"; then
    fail "$package remains explicitly selected in the DINX profile"
  fi
  if grep -Fq "\"$package\"" "$feature_groups"; then
    fail "$package remains in an ISO feature group"
  fi
done
for retired in vlc vlc-cli wordcraft gridcraft deckcraft pdfcraft onlyoffice zrythm impasto floorp topgrade; do
  if grep -Fqx "    - $retired" "$profile" || grep -Fq "\"$retired\"" "$feature_groups"; then
    fail "$retired remains explicitly selected for the DINX ISO"
  fi
done
[[ ! -e "$local_apps/vlc.desktop" ]] || fail 'retired VLC desktop override remains in the ISO overlay'
haruna_recipe="$root/distro/packages/haruna/PKGBUILD"
haruna_source="$root/distro/packages/haruna/source.env"
source "$haruna_source"
[[ "$HARUNA_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Haruna version: $HARUNA_VERSION"
[[ "$HARUNA_SOURCE_URL" == "https://download.kde.org/stable/haruna/${HARUNA_VERSION}/haruna-${HARUNA_VERSION}.tar.xz" ]] \
  || fail 'Haruna source URL does not match its stable release pin'
[[ "$HARUNA_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'Haruna source checksum is invalid'
[[ -x "$haruna_wrapper" ]] || fail 'Haruna dark-theme launcher is missing or not executable'
sh -n "$haruna_wrapper" || fail 'Haruna dark-theme launcher has invalid shell syntax'
grep -Fq "scheme='DINX Dark'" "$haruna_wrapper" || fail 'Haruna launcher does not default to the DINX dark color scheme'
grep -Fq -- '--key ColorScheme "$scheme"' "$haruna_wrapper" || fail 'Haruna launcher does not force its application color scheme'
grep -Fq 'exec /usr/bin/haruna "$@"' "$haruna_wrapper" || fail 'Haruna launcher does not preserve launch arguments'
[[ -r "$haruna_scheme" ]] || fail 'DINX KDE color scheme is missing'
grep -Fqx 'Name=DINX Dark' "$haruna_scheme" || fail 'DINX KDE color scheme has an incorrect name'
grep -Fqx 'BackgroundNormal=11,13,18' "$haruna_scheme" || fail 'DINX KDE color scheme does not use the dark DINX surface'
grep -Fq 'pkgver="$HARUNA_VERSION"' "$haruna_recipe" || fail 'Haruna package version is not wired to source.env'
grep -Fq '${HARUNA_SOURCE_URL}' "$haruna_recipe" || fail 'Haruna source URL is not wired to source.env'
grep -Fq '"$HARUNA_SOURCE_SHA256"' "$haruna_recipe" || fail 'Haruna checksum is not wired to source.env'
grep -Fq 'build_package haruna' "$root/scripts/build-iso-container.sh" || fail 'ISO builder does not build Haruna'
for dependency in ffmpeg mpvqt qt6-base qt6-declarative; do
  grep -Fqx "  $dependency" "$haruna_recipe" || fail "Haruna dependency is missing: $dependency"
done
grep -Fqx 'makedepends=(extra-cmake-modules)' "$haruna_recipe" || fail 'Haruna extra-cmake-modules build dependency is missing'
grep -Fqx 'extra-cmake-modules' "$root/scripts/iso-builder/packages.txt" || fail "Artix builder omits Haruna's build dependency"
for mime in video/mp4 video/mpeg video/webm video/x-matroska; do
  grep -Fqx "$mime=org.kde.haruna.desktop;" "$mimeapps" || fail "Haruna is not the default video handler for $mime"
done
for mime in text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https; do
  grep -Fqx "$mime=firefox.desktop;" "$mimeapps" || fail "Firefox is not the default handler for $mime"
done
grep -Fqx 'application/pdf=eurooffice.desktop;' "$mimeapps" || fail 'EuroOffice is not the default PDF handler'
if grep -Fq 'floorp.desktop\|onlyoffice.desktop' "$mimeapps"; then
  fail 'MIME defaults retain a retired browser or office desktop entry'
fi
if grep -Fq 'vlc.desktop' "$mimeapps"; then
  fail 'MIME defaults retain the retired VLC desktop entry'
fi
if grep -Fqx '    - kolourpaint' "$profile"; then
  fail 'KolourPaint remains in the DINX profile'
fi
if [[ -e "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/org.kde.kolourpaint.desktop" ]]; then
  fail 'retired KolourPaint desktop override remains in the ISO overlay'
fi
for package in patchy blockbench paintfe transit zenkai; do
  launcher="$root/distro/packages/$package/$package.desktop"
  [[ -r "$launcher" ]] || fail "$package desktop launcher is missing"
  grep -Fqx '[Desktop Entry]' "$launcher" || fail "$package desktop launcher has no entry header"
  case "$package" in
    patchy) expected_name=Patchy ;;
    blockbench) expected_name=Blockbench ;;
    paintfe) expected_name=PaintFE ;;
    transit) expected_name=Transit ;;
    zenkai) expected_name=Zenkai ;;
  esac
  grep -Fqx "Name=$expected_name" "$launcher" || fail "$package desktop launcher name is missing"
  grep -Fqx "Name[pt_BR]=$expected_name" "$launcher" || fail "$package Portuguese desktop launcher name is missing"
  grep -Fqx "TryExec=$package" "$launcher" || fail "$package desktop launcher prerequisite is incorrect"
  case "$package" in
    paintfe|transit)
      grep -Eq '^MimeType=[^;]+;' "$launcher" || fail "$package desktop launcher registers no MIME types"
      ;;
  esac
  grep -Fq '!strip' "$root/distro/packages/$package/PKGBUILD" || fail "$package AppImage package must disable binary stripping"
  if grep -Eq "^(Hidden|NoDisplay)=true$" "$launcher"; then
    fail "$package desktop launcher is hidden"
  fi
done
pixelorama_source="$root/distro/packages/pixelorama/source.env"
pixelorama_recipe="$root/distro/packages/pixelorama/PKGBUILD"
pixelorama_launcher="$root/distro/packages/pixelorama/pixelorama"
pixelorama_desktop="$root/distro/packages/pixelorama/pixelorama.desktop"
source "$pixelorama_source"
[[ "$PIXELORAMA_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Pixelorama version: $PIXELORAMA_VERSION"
[[ "$PIXELORAMA_SOURCE_URL" == "https://github.com/Orama-Interactive/Pixelorama/releases/download/v${PIXELORAMA_VERSION}/Pixelorama-Linux-64bit.tar.gz" ]] \
  || fail 'Pixelorama source URL does not match its pinned release'
for checksum in "$PIXELORAMA_SOURCE_SHA256" "$PIXELORAMA_LICENSE_SHA256" "$PIXELORAMA_ICON_SHA256" "$PIXELORAMA_MIME_SHA256"; do
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail 'Pixelorama source checksum is invalid'
done
grep -Fq 'pkgver="$PIXELORAMA_VERSION"' "$pixelorama_recipe" || fail 'Pixelorama package version is not wired to source.env'
for pin in PIXELORAMA_SOURCE_SHA256 PIXELORAMA_LICENSE_SHA256 PIXELORAMA_ICON_SHA256 PIXELORAMA_MIME_SHA256; do
  grep -Fq "\"\$$pin\"" "$pixelorama_recipe" || fail "Pixelorama package does not verify $pin"
done
grep -Fq '!strip' "$pixelorama_recipe" || fail 'Pixelorama release binary must not be stripped'
grep -Fq '${PIXELORAMA_SOURCE_URL}' "$pixelorama_recipe" || fail 'Pixelorama source URL is not wired to source.env'
[[ -x "$pixelorama_launcher" ]] || fail 'Pixelorama launcher is missing or not executable'
bash -n "$pixelorama_launcher" || fail 'Pixelorama launcher has invalid shell syntax'
grep -Fqx 'exec /opt/pixelorama/Pixelorama.x86_64 "$@"' "$pixelorama_launcher" || fail 'Pixelorama launcher does not pass arguments to the packaged binary'
grep -Fqx 'Name=Pixelorama' "$pixelorama_desktop" || fail 'Pixelorama desktop name is missing'
grep -Fqx 'Name[pt_BR]=Pixelorama' "$pixelorama_desktop" || fail 'Pixelorama Portuguese desktop name is missing'
grep -Fqx 'Exec=pixelorama %u' "$pixelorama_desktop" || fail 'Pixelorama desktop command is incorrect'
grep -Fqx 'TryExec=pixelorama' "$pixelorama_desktop" || fail 'Pixelorama desktop prerequisite is incorrect'
if grep -Eq '^(Hidden|NoDisplay)=true$' "$pixelorama_desktop"; then
  fail 'Pixelorama desktop entry is hidden'
fi
grep -Fq 'build_package pixelorama' "$root/scripts/build-iso-container.sh" || fail 'ISO builder does not build Pixelorama'


