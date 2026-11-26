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
local_apps="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications"
calamares_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/calamares.desktop"
dinx_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-installer.desktop"
desktop_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/Desktop/Install DINX.desktop"
desktop_approval="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-approve-desktop-launcher"
display_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/network.cycles.wdisplays.desktop"
live_policy="$root/distro/iso/iso-profiles/dinx/live-overlay/etc/polkit-1/rules.d/00-dinx-live-passwordless.rules"
haruna_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/haruna"
haruna_scheme="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/color-schemes/DINXDark.colors"
gapless_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/g4music"
gapless_alias="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/gapless"
pori_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/pori"
haruna_override="$local_apps/org.kde.haruna.desktop"
qt6ct_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/qt6ct.conf"
pcmanfm_override="$local_apps/pcmanfm.desktop"
libexec_dir="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec"
retired_overrides=(vlc.desktop onlyoffice.desktop org.onlyoffice.desktop org.aqueous.Phyto.desktop)


fail() {
  printf 'desktop_packages_contract: FAIL: %s\n' "$1" >&2
  exit 1
}
[[ -x "$bluetooth_helper" ]] || fail 'DINX Bluetooth launcher is missing or not executable'
sh -n "$bluetooth_helper" || fail 'DINX Bluetooth launcher has invalid shell syntax'
grep -Fqx 'exec /usr/bin/g4music "$@"' "$gapless_wrapper" || fail 'Gapless wrapper can recurse instead of launching the packaged binary'
grep -Fqx 'exec /usr/bin/g4music "$@"' "$gapless_alias" || fail 'Gapless alias can recurse instead of launching the packaged binary'
grep -Fqx 'Exec=haruna %U' "$haruna_override" || fail 'Haruna does not use its DINX launcher'
grep -Fqx 'color_scheme_path=~/.config/qt6ct/colors/DINX.conf' "$qt6ct_config" || fail 'Qt6ct does not select the DINX dark palette'
grep -Fqx 'custom_palette=true' "$qt6ct_config" || fail 'Qt6ct DINX dark palette is disabled'
grep -Fqx 'Name=Display Settings' "$display_launcher" || fail 'Display launcher English name is incorrect'
grep -Fqx 'Exec=dinx-wdisplays' "$display_launcher" || fail 'Display launcher does not use the persistence wrapper'

for package in firewalld firewall-config file-roller galculator gapless gparted haruna sane fwupd flatpak pcmanfm pori shikane udisks2 udisks2-btrfs wdisplays papirus-icon-theme; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done
for disabled_package in pixelorama paintfe blender godot krita inkscape patchy audionaut; do
  if grep -Fqx "    - $disabled_package" "$profile" || grep -Fq "\"$disabled_package\"" "$feature_groups"; then
    fail "$disabled_package is disabled for the NEXT ISO but remains selected"
  fi
done
for package in qogir-icon-theme breeze-icons breeze breeze-cursors qqc2-breeze-style plasma-integration plasma-workspace xdg-desktop-portal-kde zathura zathura-pdf-mupdf libmupdf; do
  if grep -Fqx "    - $package" "$profile"; then
    fail "$package remains explicitly selected in the DINX profile"
  fi
  if grep -Fq "\"$package\"" "$feature_groups"; then
    fail "$package remains in an ISO feature group"
  fi
done
# River/KWM/Morghulis rework retired these apps from the roster; assert they stay
# out of both the profile and the ISO feature groups so a future edit cannot
# silently reintroduce a recipe-less or Pearl/office-coupled app.
for retired in vlc vlc-cli zrythm impasto onlyoffice seafoam-settings floorp transit zenkai blockbench; do
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
if grep -Fqx '    - strawberry' "$profile"; then
  fail 'Strawberry remains in the DINX profile'
fi
gapless_recipe="$root/distro/packages/gapless/PKGBUILD"
gapless_source="$root/distro/packages/gapless/source.env"
source "$gapless_source"
[[ "$GAPLESS_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Gapless version: $GAPLESS_VERSION"
[[ "$GAPLESS_SOURCE_URL" == *"/g4music-v${GAPLESS_VERSION}.tar.gz" ]] \
  || fail 'Gapless source URL does not match its version pin'
[[ "$GAPLESS_SOURCE_B2" =~ ^[0-9a-f]{128}$ ]] || fail 'Gapless BLAKE2 checksum is invalid'
grep -Fq 'pkgver="$GAPLESS_VERSION"' "$gapless_recipe" \
  || fail 'Gapless package version is not wired to source.env'
grep -Fq '${GAPLESS_SOURCE_URL}' "$gapless_recipe" \
  || fail 'Gapless package URL is not wired to source.env'
grep -Fq '"$GAPLESS_SOURCE_B2"' "$gapless_recipe" \
  || fail 'Gapless package checksum is not wired to source.env'
grep -Fqx '  gst-plugins-base' "$gapless_recipe" || fail 'Gapless package does not require GStreamer base codecs'
grep -Fqx '  gst-plugins-good' "$gapless_recipe" || fail 'Gapless package does not require GStreamer good codecs'
if grep -Fqx 'DBusActivatable=true' "$local_apps/com.github.neithern.g4music.desktop"; then
  fail 'Gapless must inherit the active Wayland environment instead of using session D-Bus activation'
fi
grep -Fqx 'Name=Archive Manager' "$file_roller_override" || fail 'File Roller English desktop name is missing'
grep -Fqx 'Name[pt_BR]=Descompactador' "$file_roller_override" || fail 'File Roller Portuguese desktop name is missing'
grep -Fqx 'TryExec=file-roller' "$file_roller_override" || fail 'File Roller override does not resolve the installed binary'
grep -Fqx 'Exec=file-roller %U' "$file_roller_override" || fail 'File Roller override does not preserve file opening'
grep -Fqx 'Icon=org.gnome.FileRoller' "$file_roller_override" || fail 'File Roller override icon is missing'
grep -Fq 'bluetoothctl list' "$bluetooth_helper" || fail 'Bluetooth launcher does not detect available controllers'
grep -Fq 'exec blueman-manager' "$bluetooth_helper" || fail 'Bluetooth launcher does not open Blueman when a controller exists'
while IFS='|' read -r desktop_id english portuguese command; do
  desktop="$local_apps/$desktop_id"
  [[ -f "$desktop" ]] || fail "missing localized desktop override: $desktop_id"
  grep -Fqx "Name=$english" "$desktop" || fail "$desktop_id English desktop name is incorrect"
  grep -Fqx "Name[pt_BR]=$portuguese" "$desktop" || fail "$desktop_id Portuguese desktop name is incorrect"
  grep -Fqx "Exec=$command" "$desktop" || fail "$desktop_id launch command is incorrect"
done <<'EOF'
pcmanfm.desktop|File Manager|Gerenciador de Arquivos|pcmanfm %U
galculator.desktop|Calculator|Calculadora|galculator
gparted.desktop|Partition Editor|Particionador|/usr/local/libexec/dinx-gparted %f
swayimg.desktop|Image Viewer|Visualizador de Imagens|swayimg %F
com.github.neithern.g4music.desktop|Music Player|Tocador de Música|env GTK_THEME=DINX GTK_APPLICATION_PREFER_DARK_THEME=1 g4music %U
org.kde.haruna.desktop|Media Player|Tocador de Mídia|haruna %U
blueman-manager.desktop|Bluetooth|Bluetooth|/usr/local/libexec/dinx-bluetooth-manager
nm-connection-editor.desktop|Network Connections|Ajustes de Rede|nm-connection-editor
com.saivert.pwvucontrol.desktop|Audio Control|Ajustes de Áudio|pwvucontrol
EOF
grep -Fqx 'NoDisplay=true' "$local_apps/swayimg.desktop" || fail 'Swayimg was exposed as a standalone menu item'
grep -Fqx 'Name=Services' "$root/distro/packages/dinitui/resources/dinitui.desktop" || fail 'DinitUI English desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Serviços' "$root/distro/packages/dinitui/resources/dinitui.desktop" || fail 'DinitUI Portuguese desktop name is incorrect'
grep -Fqx 'Name=Control Center' "$root/distro/packages/dinxpanel/resources/dinxpanel.desktop" || fail 'DINXPanel English desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Central de Controle' "$root/distro/packages/dinxpanel/resources/dinxpanel.desktop" || fail 'DINXPanel Portuguese desktop name is incorrect'
grep -Fqx '+Name=Editor' "$root/distro/packages/deetty/product-identity.patch" || fail 'Dintor English desktop name is incorrect'
grep -Fqx '+Name[pt_BR]=Editor' "$root/distro/packages/deetty/product-identity.patch" || fail 'Dintor Portuguese desktop name is incorrect'
grep -Fqx 'Name=Disks & Mounts' "$root/distro/packages/pori/PKGBUILD" || fail 'Pori English desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Discos e Montagens' "$root/distro/packages/pori/PKGBUILD" || fail 'Pori Portuguese desktop name is incorrect'
grep -Fqx 'Name=Display Settings' "$display_launcher" || fail 'Display launcher English desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Ajustes de Tela' "$display_launcher" || fail 'Display launcher Portuguese desktop name is incorrect'
grep -Fqx 'Name=Install DINX' "$dinx_installer" || fail 'DINX installer English desktop name is missing'
grep -Fqx 'Name[pt_BR]=Instalar DINX' "$dinx_installer" || fail 'DINX installer Portuguese desktop name is missing'
grep -Fqx 'Exec=/usr/local/libexec/dinx-installer' "$dinx_installer" || fail 'DINX installer does not use its session-aware launcher'
grep -Fqx 'TryExec=/usr/local/libexec/dinx-installer' "$dinx_installer" || fail 'DINX installer launcher prerequisite is incorrect'
[[ -f "$desktop_installer" ]] || fail 'live-user skeleton omits the Install DINX desktop shortcut'
grep -Fqx 'Name=Install DINX' "$desktop_installer" || fail 'desktop shortcut English name is missing'
grep -Fqx 'Name[pt_BR]=Instalar DINX' "$desktop_installer" || fail 'desktop shortcut Portuguese name is missing'
grep -Fqx 'Exec=/usr/local/libexec/dinx-installer' "$desktop_installer" || fail 'desktop shortcut does not use the session-aware launcher'
grep -Fqx 'TryExec=/usr/local/libexec/dinx-installer' "$desktop_installer" || fail 'desktop shortcut launcher prerequisite is incorrect'
grep -Fq 'xdg-user-dir DESKTOP' "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-session" || fail 'live session does not resolve the provisioned desktop directory'
grep -Fq 'installer_seed=/etc/skel/Desktop/Install\ DINX.desktop' "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-session" || fail 'live session does not seed the installer shortcut from /etc/skel'
installer_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-installer"
[[ -x "$installer_helper" ]] || fail 'DINX installer helper is missing or not executable'
sh -n "$installer_helper" || fail 'DINX installer helper has invalid shell syntax'
grep -Fq 'output=$(pkexec env \' "$installer_helper" || fail 'DINX installer does not elevate Calamares through pkexec'
grep -Fq '    calamares 2>&1)' "$installer_helper" || fail 'DINX installer does not execute Calamares as the elevated command'
for variable in XDG_RUNTIME_DIR WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_SESSION_TYPE QT_QPA_PLATFORM; do
  grep -Fq "    $variable=" "$installer_helper" || fail "DINX installer does not preserve $variable across pkexec"
done
grep -Fqx '    - zenity' "$profile" || fail 'profile is missing the installer error-dialog dependency'
grep -Fqx '    - polkit' "$profile" || fail 'profile is missing the polkit pkexec provider'
grep -Fqx '    - lxqt-policykit' "$profile" || fail 'profile is missing the Wayland polkit authorization agent'
grep -Fqx '    - procps-ng' "$profile" || fail 'profile is missing pgrep for the installer agent prerequisite check'
grep -Fqx '  usr/bin/pgrep' "$iso_check" || fail 'ISO payload is missing pgrep'
grep -Fqx '  usr/bin/pkexec' "$iso_check" || fail 'ISO payload is missing pkexec'
grep -Fqx '  usr/bin/lxqt-policykit-agent' "$iso_check" || fail 'ISO payload is missing the Wayland polkit agent'
grep -Fqx '  usr/local/libexec/dinx-installer' "$iso_check" || fail 'ISO payload is missing the DINX installer helper'
grep -Fqx '  usr/bin/zenity' "$iso_check" || fail 'ISO payload is missing the installer error-dialog dependency'
grep -Fqx '  usr/share/applications/calamares.desktop' "$iso_check" || fail 'ISO content contract omits the Calamares desktop-ID mask'
grep -Fqx 'Type=Application' "$calamares_launcher" || fail 'Calamares desktop-ID mask has an invalid type'
grep -Fqx 'Name=Calamares' "$calamares_launcher" || fail 'Calamares desktop-ID mask is missing its desktop name'
grep -Fqx 'Hidden=true' "$calamares_launcher" || fail 'Calamares Artix launcher is not deleted from the desktop namespace'
grep -Fqx 'NoDisplay=true' "$calamares_launcher" || fail 'Calamares Artix launcher remains visible in application menus'
if grep -Eiq "Install Artix|Instalar Artix|^(Exec|TryExec)=" "$calamares_launcher"; then
  fail 'Calamares desktop-ID mask retains an Artix identity or executable'
fi
artix_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/artix-installer.desktop"
[[ ! -e "$artix_launcher" ]] || fail 'live ISO overlay ships the redundant Artix installer launcher'
if grep -Fqx 'Hidden=true' "$dinx_installer" || grep -Fqx 'NoDisplay=true' "$dinx_installer"; then
  fail 'DINX installer shortcut is hidden'
fi
for override in pcmanfm.desktop galculator.desktop gparted.desktop swayimg.desktop com.github.neithern.g4music.desktop org.kde.haruna.desktop blueman-manager.desktop nm-connection-editor.desktop com.saivert.pwvucontrol.desktop; do
  grep -Fqx "  usr/local/share/applications/$override" "$iso_check" || fail "ISO payload is missing the launcher override: $override"
done
for mime in application/zip application/x-7z-compressed application/vnd.rar application/x-rar application/x-tar application/gzip application/x-gzip application/x-bzip2 application/x-xz application/zstd; do
  grep -Fqx "$mime=org.gnome.FileRoller.desktop;" "$file_roller_mime_cache" || fail "localized File Roller MIME cache is missing $mime"
done
for mime in application/zip application/x-7z-compressed application/vnd.rar application/x-rar application/x-tar application/gzip application/x-gzip application/x-bzip2 application/x-xz application/zstd; do
  grep -Fq "$mime;" "$file_roller_override" || fail "localized File Roller launcher does not claim $mime"
done

grep -Fqx '  usr/bin/scanimage' "$iso_check" || fail 'ISO payload is missing scanimage'
grep -Fqx '  usr/bin/fwupdmgr' "$iso_check" || fail 'ISO payload is missing fwupdmgr'
grep -Fqx '  usr/bin/flatpak' "$iso_check" || fail 'ISO payload is missing flatpak'
grep -Fqx '  usr/bin/pcmanfm' "$iso_check" || fail 'ISO payload is missing PCManFM'
grep -Fqx '  usr/bin/g4music' "$iso_check" || fail 'ISO payload is missing Gapless'
grep -Fqx '  usr/bin/galculator' "$iso_check" || fail 'ISO payload is missing Galculator'
grep -Fqx '  usr/share/flatpak/remotes.d/flathub.flatpakrepo' "$iso_check" || fail 'ISO payload is missing the Flatpak source descriptor'
grep -Fqx '  usr/share/applications/com.pori.app.desktop' "$iso_check" || fail 'ISO payload is missing the Pori desktop entry'
grep -Fqx '  usr/local/share/applications/pcmanfm.desktop' "$iso_check" || fail 'ISO payload is missing the PCManFM desktop override'
grep -Fqx '  usr/share/applications/com.github.neithern.g4music.desktop' "$iso_check" || fail 'ISO payload is missing the Gapless desktop entry'
grep -Fqx '  usr/share/applications/galculator.desktop' "$iso_check" || fail 'ISO payload is missing the Galculator desktop entry'
grep -Fqx '  usr/bin/file-roller' "$iso_check" || fail 'ISO payload is missing File Roller'
grep -Fqx '  usr/bin/gparted' "$iso_check" || fail 'ISO payload is missing GParted'
grep -Fqx '  usr/bin/shikane' "$iso_check" || fail 'ISO payload is missing Shikane'
grep -Fqx '  usr/bin/shikanectl' "$iso_check" || fail 'ISO payload is missing shikanectl'
grep -Fqx '  usr/bin/wdisplays' "$iso_check" || fail 'ISO payload is missing wdisplays'
grep -Fqx '  usr/share/applications/org.gnome.FileRoller.desktop' "$iso_check" || fail 'ISO payload is missing the File Roller desktop entry'
grep -Fqx '  usr/local/share/applications/org.gnome.FileRoller.desktop' "$iso_check" || fail 'ISO payload is missing the localized File Roller desktop override'
grep -Fqx '  usr/local/share/applications/mimeinfo.cache' "$iso_check" || fail 'ISO payload is missing the localized File Roller MIME cache'
grep -Fqx '  usr/share/applications/gparted.desktop' "$iso_check" || fail 'ISO payload is missing the GParted desktop entry'
grep -Fqx '  usr/share/applications/network.cycles.wdisplays.desktop' "$iso_check" || fail 'ISO payload is missing the wdisplays desktop entry'
grep -Fqx '  usr/share/applications/firewall-config.desktop' "$iso_check" || fail 'ISO payload is missing the firewall-config desktop entry'
if grep -Fq 'strawberry' "$mimeapps"; then
  fail 'Strawberry remains in the audio handler defaults'
fi
for mime in audio/mpeg audio/x-mpeg audio/x-mp3 audio/ogg audio/x-vorbis audio/x-vorbis+ogg audio/x-opus+ogg audio/flac audio/x-flac audio/wav audio/x-wav; do
  grep -Fqx "$mime=com.github.neithern.g4music.desktop;" "$mimeapps" || fail "Gapless is not the default audio handler for $mime"
done
grep -Fqx 'image/png=swayimg.desktop;' "$mimeapps" || fail 'Swayimg is no longer the default image viewer'
grep -Fqx 'application/pdf=firefox.desktop;' "$mimeapps" || fail 'Firefox is not the default PDF handler'
if grep -Fq 'application/epub+zip=' "$mimeapps"; then
  fail 'EPUB handler still points to the removed Zathura application'
fi
grep -Fqx 'inode/directory=pcmanfm.desktop;' "$mimeapps" || fail 'PCManFM is no longer the default directory handler'
for mime in application/zip application/x-7z-compressed application/vnd.rar application/x-rar application/x-tar application/gzip application/x-gzip application/x-bzip2 application/x-xz application/zstd; do
  grep -Fqx "$mime=org.gnome.FileRoller.desktop;" "$mimeapps" || fail "File Roller is not the default archive handler for $mime"
done

printf 'desktop_packages_contract calculator=galculator gapless=true codecs=gstreamer-base+good strawberry=false bilingual_launchers=true artix_alias_absent=true calamares_package_launcher_masked=true dinx_installer_visible=true installer_prerequisites_declared=true firewall=firewalld+firewall-config process_manager=localized no_traffic_monitor=true sane=true fwupd=true flatpak=true creative_apps=disabled kolourpaint=false icon_theme=papirus qogir=false breeze=false zathura=false libmupdf=false pdf_handler=firefox graphics_apps=disabled office=optional-channel impasto=false onlyoffice=false zrythm=false seafoam=false pori=true pcmanfm=true archive_tool=file-roller partition_editor=gparted display_tools=wdisplays+shikane directory_handler=pcmanfm\n'
