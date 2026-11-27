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
pcmanfm_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/pcmanfm.desktop"
retired_overrides=(qps.desktop org.aqueous.Phyto.desktop com.shellyorg.shelly.desktop org.aqueous.Dome.desktop)
local_apps="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications"
calamares_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/calamares.desktop"
dinx_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-installer.desktop"
desktop_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/Desktop/Install DINX.desktop"
godot_settings="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/godot/editor_settings-4.tres"
godot_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/godot"
desktop_approval="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-approve-desktop-launcher"
display_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/network.cycles.wdisplays.desktop"
live_policy="$root/distro/iso/iso-profiles/dinx/live-overlay/etc/polkit-1/rules.d/00-dinx-live-passwordless.rules"
haruna_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/haruna"
haruna_scheme="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/color-schemes/DINXDark.colors"

fail() {
  printf 'desktop_packages_contract: FAIL: %s\n' "$1" >&2
  exit 1
}
[[ -r "$godot_settings" ]] || fail 'Godot editor settings are missing'
grep -Fq 'interface/editor/display_scale = 2' "$godot_settings" \
  || fail 'Godot editor display scale is not fixed at 100%'
grep -Fq 'interface/editor/custom_display_scale = 1.0' "$godot_settings" \
  || fail 'Godot editor custom display scale is not 100%'
[[ -x "$godot_launcher" ]] || fail 'Godot launcher wrapper is missing or not executable'
grep -Fq -- '--display-driver wayland' "$godot_launcher" \
  || fail 'Godot launcher does not select the decorated Wayland path'
[[ -x "$bluetooth_helper" ]] || fail 'DINX Bluetooth launcher is missing or not executable'
sh -n "$bluetooth_helper" || fail 'DINX Bluetooth launcher has invalid shell syntax'
grep -Fqx 'Name=Display Settings' "$display_launcher" || fail 'Display launcher English name is incorrect'
grep -Fqx 'Exec=dinx-wdisplays' "$display_launcher" || fail 'Display launcher does not use the persistence wrapper'

for package in firewalld firewall-config file-roller fwupd galculator gapless gparted haruna flatpak paintfe krita inkscape godot pixelorama patchy pori shikane udisks2 udisks2-btrfs wdisplays firefox eurooffice papirus-icon-theme tuxmanager; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done
for package in pcmanfm blender audionaut octopi pacman-contrib libdecor wizp-lean; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
  jq -e --arg package "$package" '.groups.desktop.packages | index($package) != null' "$feature_groups" >/dev/null \
    || fail "desktop feature group is missing $package"
done
for package in qogir-icon-theme breeze-icons breeze breeze-cursors qqc2-breeze-style plasma-integration plasma-workspace xdg-desktop-portal-kde zathura zathura-pdf-mupdf libmupdf; do
  if grep -Fqx "    - $package" "$profile"; then
    fail "$package remains explicitly selected in the DINX profile"
  fi
  if grep -Fq "\"$package\"" "$feature_groups"; then
    fail "$package remains in an ISO feature group"
  fi
done
for retired in vlc vlc-cli wordcraft gridcraft deckcraft pdfcraft onlyoffice zrythm impasto floorp topgrade \
  qps glances sane blockbench transit zenkai phyto dome shelly seafoam-settings; do
  # glances stays in scripts/iso-builder/packages.txt for the builder-only Deetty P2
  # qualification; it must not be selected for the ISO itself.
  if grep -Fqx "    - $retired" "$profile" || grep -Fq "\"$retired\"" "$feature_groups"; then
    fail "$retired remains explicitly selected for the DINX ISO"
  fi
done
for retired_override in "${retired_overrides[@]}"; do
  if [[ -e "$local_apps/$retired_override" ]]; then
    fail "retired $retired_override desktop override remains in the ISO overlay"
  fi
done
for retired_recipe in blockbench transit phyto dome shelly seafoam-settings zenkai; do
  if [[ -e "$root/distro/packages/$retired_recipe" ]]; then
    fail "retired $retired_recipe package recipe remains in the tree"
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
grep -Fqx 'inode/directory=pcmanfm.desktop;' "$mimeapps" || fail 'pcmanfm is not the default directory handler'
if grep -Fq 'org.aqueous.Phyto.desktop' "$mimeapps"; then
  fail 'MIME defaults retain the retired Phyto directory handler'
fi
[[ -r "$pcmanfm_override" ]] || fail 'the pcmanfm file manager desktop override is missing'
grep -Fqx 'Exec=pcmanfm %U' "$pcmanfm_override" || fail 'the pcmanfm desktop override command is incorrect'
grep -Fqx 'TryExec=pcmanfm' "$pcmanfm_override" || fail 'the pcmanfm desktop override prerequisite is incorrect'
grep -Fqx 'MimeType=inode/directory;' "$pcmanfm_override" || fail 'the pcmanfm desktop override does not register inode/directory'
if grep -Eq '^(Hidden|NoDisplay)=true$' "$pcmanfm_override"; then
  fail 'the pcmanfm desktop override is hidden'
fi
grep -Fq 'start_optional desktop "$libexec_dir/dinx-pcmanfm-desktop"' "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor" \
  || fail 'the DINX session supervisor does not start the PCManFM desktop wrapper'
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
for package in patchy paintfe; do
  launcher="$root/distro/packages/$package/$package.desktop"
  [[ -r "$launcher" ]] || fail "$package desktop launcher is missing"
  grep -Fqx '[Desktop Entry]' "$launcher" || fail "$package desktop launcher has no entry header"
  case "$package" in
    patchy) expected_name=Patchy ;;
    paintfe) expected_name=PaintFE ;;
  esac
  grep -Fqx "Name=$expected_name" "$launcher" || fail "$package desktop launcher name is missing"
  grep -Fqx "Name[pt_BR]=$expected_name" "$launcher" || fail "$package Portuguese desktop launcher name is missing"
  grep -Fqx "TryExec=$package" "$launcher" || fail "$package desktop launcher prerequisite is incorrect"
  if [[ "$package" == paintfe ]]; then
    grep -Eq '^MimeType=[^;]+;' "$launcher" || fail "$package desktop launcher registers no MIME types"
  fi
  grep -Fq '!strip' "$root/distro/packages/$package/PKGBUILD" || fail "$package AppImage package must disable binary stripping"
  if grep -Eq "^(Hidden|NoDisplay)=true$" "$launcher"; then
    fail "$package desktop launcher is hidden"
  fi
  grep -Fq "build_package $package" "$root/scripts/build-iso-container.sh" || fail "ISO builder does not build $package"
done
paintfe_launcher="$root/distro/packages/paintfe/paintfe"
[[ -x "$paintfe_launcher" ]] || fail 'PaintFE launcher is missing or not executable'
sh -n "$paintfe_launcher" || fail 'PaintFE launcher has invalid shell syntax'
grep -Fqx 'exec /opt/paintfe/AppRun "$@"' "$paintfe_launcher" \
  || fail 'PaintFE launcher does not exec the pre-extracted AppRun tree'
grep -Fqx 'export GTK_APPLICATION_PREFER_DARK_THEME=1' "$paintfe_launcher" \
  || fail 'PaintFE launcher does not request the dark GTK theme'

tuxmanager_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/tux-manager"
blender_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/blender"
eurooffice_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/eurooffice"
for wrapper in "$tuxmanager_wrapper" "$blender_wrapper" "$eurooffice_wrapper"; do
  [[ -x "$wrapper" ]] || fail "DINX wrapper is missing or not executable: ${wrapper#$root/}"
  sh -n "$wrapper" || fail "DINX wrapper has invalid shell syntax: ${wrapper#$root/}"
done
grep -Fqx 'export QT_QPA_PLATFORMTHEME=qt6ct' "$tuxmanager_wrapper" \
  || fail 'TuxManager wrapper does not use qt6ct'
grep -Fqx 'export QT_STYLE_OVERRIDE=fusion' "$tuxmanager_wrapper" \
  || fail 'TuxManager wrapper does not force the Fusion dark-capable style'
grep -Fqx 'exec /usr/bin/tux-manager "$@"' "$tuxmanager_wrapper" \
  || fail 'TuxManager wrapper does not exec the packaged binary'
grep -Fqx 'exec /usr/bin/blender --factory-startup "$@"' "$blender_wrapper" \
  || fail 'Blender wrapper does not bypass a broken user startup.blend'
grep -Fqx 'export GTK_APPLICATION_PREFER_DARK_THEME=1' "$eurooffice_wrapper" \
  || fail 'EuroOffice overlay wrapper does not request the dark GTK theme'
grep -Fqx 'export QT_QPA_PLATFORMTHEME=qt6ct' "$eurooffice_wrapper" \
  || fail 'EuroOffice overlay wrapper does not use qt6ct'
grep -Fqx 'exec /usr/bin/eurooffice --theme=dark "$@"' "$eurooffice_wrapper" \
  || fail 'EuroOffice overlay wrapper does not pass the dark theme to the staged binary'

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
audionaut_source="$root/distro/packages/audionaut/source.env"
audionaut_recipe="$root/distro/packages/audionaut/PKGBUILD"
audionaut_launcher="$root/distro/packages/audionaut/audionaut"
audionaut_desktop="$root/distro/packages/audionaut/audionaut.desktop"
for recipe_file in "$audionaut_source" "$audionaut_recipe" "$audionaut_launcher" "$audionaut_desktop"; do
  [[ -r "$recipe_file" ]] || fail "Audionaut contract file is missing: ${recipe_file#$root/}"
done
source "$audionaut_source"
[[ "$AUDIONAUT_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Audionaut version: $AUDIONAUT_VERSION"
[[ "$AUDIONAUT_SOURCE_URL" == "https://github.com/kvoltmer/Audionaut/releases/download/v${AUDIONAUT_VERSION}/Audionaut-${AUDIONAUT_VERSION}-x86_64.AppImage" ]] \
  || fail 'Audionaut source URL does not match its pinned AppImage release'
[[ "$AUDIONAUT_LICENSE_URL" == "https://raw.githubusercontent.com/kvoltmer/Audionaut/v${AUDIONAUT_VERSION}/LICENSE.md" ]] \
  || fail 'Audionaut license URL does not match its pinned release'
for pin in AUDIONAUT_SOURCE_SHA256 AUDIONAUT_LICENSE_SHA256; do
  [[ "${!pin}" =~ ^[0-9a-f]{64}$ ]] || fail "Audionaut $pin is invalid"
  grep -Fq "\"\$$pin\"" "$audionaut_recipe" || fail "Audionaut package does not verify $pin"
done
grep -Fq 'pkgver="$AUDIONAUT_VERSION"' "$audionaut_recipe" || fail 'Audionaut package version is not wired to source.env'
grep -Fq '${AUDIONAUT_SOURCE_URL}' "$audionaut_recipe" || fail 'Audionaut source URL is not wired to source.env'
grep -Fq '!strip' "$audionaut_recipe" || fail 'Audionaut AppImage package must disable binary stripping'
[[ -x "$audionaut_launcher" ]] || fail 'Audionaut launcher is missing or not executable'
sh -n "$audionaut_launcher" || fail 'Audionaut launcher has invalid shell syntax'
grep -Fqx 'exec /opt/audionaut/Audionaut.AppImage --appimage-extract-and-run "$@"' "$audionaut_launcher" \
  || fail 'Audionaut launcher does not run the packaged AppImage in extract-and-run mode'
grep -Fqx 'Name=Audionaut' "$audionaut_desktop" || fail 'Audionaut desktop name is missing'
grep -Fqx 'Name[pt_BR]=Audionaut' "$audionaut_desktop" || fail 'Audionaut Portuguese desktop name is missing'
grep -Fqx 'Exec=audionaut %F' "$audionaut_desktop" || fail 'Audionaut desktop command is incorrect'
grep -Fqx 'TryExec=audionaut' "$audionaut_desktop" || fail 'Audionaut desktop prerequisite is incorrect'
if grep -Eq '^(Hidden|NoDisplay)=true$' "$audionaut_desktop"; then
  fail 'Audionaut desktop entry is hidden'
fi
grep -Fq 'build_package audionaut' "$root/scripts/build-iso-container.sh" || fail 'ISO builder does not build Audionaut'

octopi_dir="$root/distro/packages/octopi"
octopi_recipe="$octopi_dir/PKGBUILD"
octopi_source="$octopi_dir/source.env"
for recipe_file in "$octopi_recipe" "$octopi_source"; do
  [[ -r "$recipe_file" ]] || fail "Octopi contract file is missing: ${recipe_file#$root/}"
done
grep -RqF 'pkexec' "$octopi_dir" \
  || fail 'Octopi package does not elevate through pkexec'
# octopi declares its dependencies as a multi-line depends=(...) array, so match
# the dependency tokens on their own lines rather than on the depends= line.
if grep -Eq '^[[:space:]]*(sudo|qt-sudo)([[:space:]]|$)' "$octopi_recipe"; then
  fail 'Octopi package still depends on sudo, which DINX replaced with pkexec/polkit elevation'
fi
grep -Eq '^[[:space:]]*polkit([[:space:]]|$)' "$octopi_recipe" \
  || fail 'Octopi package does not depend on polkit for pkexec elevation'
grep -Fq 'build_package octopi' "$root/scripts/build-iso-container.sh" || fail 'ISO builder does not build Octopi'

# Blender is generated on the blender branch and consumed from a verified pin.
blender_dir="$root/distro/packages/blender"
blender_recipe="$blender_dir/PKGBUILD"
blender_source="$blender_dir/source.env"
blender_pin="$root/distro/graphics/blender/blender.pin"
for blender_file in "$blender_recipe" "$blender_source" "$blender_pin" \
  "$root/scripts/lib/stage-blender.sh"; do
  [[ -r "$blender_file" ]] || fail "Blender contract file is missing: ${blender_file#$root/}"
done
grep -Fq 'scripts/lib/stage-blender.sh' "$root/scripts/build-iso-container.sh" \
  || fail 'ISO builder does not stage generated Blender packages'
grep -Fq 'pacman_install_local "$package_repo/$blender_package"' "$root/scripts/build-iso-container.sh" \
  || fail 'ISO builder does not install the pinned lean Blender package'
blender_all_deps=$(sed -n '/^depends=(/,/^)/p; /^makedepends=(/,/^)/p' "$blender_recipe")
if grep -Eq '^[[:space:]]*(intel-oneapi|usd|materialx|openvdb|opensubdiv|embree|openimagedenoise)([[:space:]]|$)' <<<"$blender_all_deps"; then
  fail 'Blender package still carries Artix bloat dependencies'
fi
blender_runtime_deps=$(sed -n '/^depends=(/,/^)/p' "$blender_recipe")
for required_dep in libepoxy libxfixes libxkbcommon libxrender libxxf86vm opencolorio openexr shaderc; do
  grep -Eq "^[[:space:]]*$required_dep([[:space:]]|$)" <<<"$blender_runtime_deps" \
    || fail "Blender runtime dependency is missing: $required_dep"
done
if grep -Eq '^[[:space:]]*(openshadinglanguage|clang|clang-libs|llvm)([[:space:]]|$)' <<<"$blender_runtime_deps"; then
  fail 'Blender runtime still pulls the Cycles OSL compiler toolchain'
fi
grep -Eq '^[[:space:]]*-DWITH_CYCLES_OSL=OFF' "$blender_recipe" \
  || fail 'Blender does not disable Cycles Open Shading Language support'
grep -Eq '^[[:space:]]*-DWITH_CYCLES_DEVICE_ONEAPI=OFF' "$blender_recipe" \
  || fail 'Blender does not disable Intel oneAPI (SYCL) device support'
if grep -Eq '^tag=blender(-staging)?/v[0-9]+(\.[0-9]+)+-dinx[1-9][0-9]*$' "$blender_pin"; then
  :
else
  fail 'Blender pin tag is invalid'
fi
grep -Eq '^package=blender-[0-9]+(\.[0-9]+)+-[0-9]+-x86_64\.pkg\.tar\.zst$' "$blender_pin" \
  || fail 'Blender lean package pin is invalid'
if grep -Eq '^tag=blender-staging/' "$blender_pin"; then
  grep -Eq '^mode=lean-only-staging$' "$blender_pin" \
    || fail 'Blender staging pin mode is invalid'
  staging_package=$(awk -F= '$1 == "package" { print $2; exit }' "$blender_pin")
  staging_full_package=$(awk -F= '$1 == "full_package" { print $2; exit }' "$blender_pin")
  [[ "$staging_package" == "$staging_full_package" ]] \
    || fail 'Blender lean-only staging pin must not advertise a supplemental package'
else
  grep -Eq '^full_package=blender-full-[0-9]+(\.[0-9]+)+-[0-9]+-x86_64\.pkg\.tar\.zst$' "$blender_pin" \
    || fail 'Blender full package pin is invalid'
fi
grep -Fq 'packed_tag=$(gh api' "$root/distro/graphics/blender/detect-release.sh" \
  || fail 'Blender detector does not compare published package releases'

if grep -RqF 'shelly' "$root/distro/packages/dinxpanel/src/main.zig" "$root/distro/packages/dinx-dock/src/main.zig"; then
  fail 'the retired Shelly package manager still backs DINXPanel or the DINX dock'
fi
grep -Fq '"octopi.desktop"' "$root/distro/packages/dinx-dock/src/main.zig" || fail 'DINX dock does not favourite octopi.desktop'
grep -Fq '"pcmanfm.desktop"' "$root/distro/packages/dinx-dock/src/main.zig" || fail 'DINX dock does not favourite pcmanfm.desktop'
grep -Fq '"octopi"' "$root/distro/packages/dinxpanel/src/main.zig" || fail 'DINXPanel does not launch Octopi as the package manager'
grep -Fq '"checkupdates"' "$root/distro/packages/dinxpanel/src/main.zig" || fail 'DINXPanel does not use checkupdates from pacman-contrib'
for artix_only in pcmanfm pacman-contrib; do
  if [[ -e "$root/distro/packages/$artix_only" ]]; then
    fail "$artix_only must ship from the Artix repository, not a local DINX recipe"
  fi
done
grep -Fq 'DesktopEditors.conf' "$root/distro/office/eurooffice/build.sh" \
  || fail 'EuroOffice launcher does not initialize the DesktopEditors settings file'
grep -Fq 'export GTK_APPLICATION_PREFER_DARK_THEME=1' "$root/distro/office/eurooffice/build.sh" \
  || fail 'EuroOffice launcher does not force the dark GTK theme'
grep -Fq 'export QT_QPA_PLATFORMTHEME=qt6ct' "$root/distro/office/eurooffice/build.sh" \
  || fail 'EuroOffice launcher does not use qt6ct'
grep -Fq 'theme=dark' "$root/distro/office/eurooffice/build.sh" \
  || fail 'EuroOffice launcher does not persist the dark Office theme'
grep -Fq -- '--theme=dark' "$root/distro/office/eurooffice/build.sh" \
  || fail 'EuroOffice launcher does not pass the dark theme to DesktopEditors'
printf 'desktop_packages_contract pcmanfm=true blender=true audionaut=true octopi=true pacman-contrib=true directory_handler=pcmanfm.desktop retired_appimage=false\n'


