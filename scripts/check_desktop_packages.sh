#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
iso_check="$root/scripts/check-iso-content.sh"
mimeapps="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"
file_roller_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/org.gnome.FileRoller.desktop"
file_roller_mime_cache="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/mimeinfo.cache"
gufw_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/gufw.desktop"
gufw_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-gufw"
bluetooth_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-bluetooth-manager"
qps_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/qps.desktop"
opensnitch_override="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications/opensnitch_ui.desktop"
local_apps="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/share/applications"
calamares_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/calamares.desktop"
dinx_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/dinx-installer.desktop"
desktop_installer="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/Desktop/Install DINX.desktop"
display_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/network.cycles.wdisplays.desktop"

fail() {
  printf 'desktop_packages_contract: FAIL: %s\n' "$1" >&2
  exit 1
}
[[ -x "$bluetooth_helper" ]] || fail 'DINX Bluetooth launcher is missing or not executable'
sh -n "$bluetooth_helper" || fail 'DINX Bluetooth launcher has invalid shell syntax'
[[ -x "$gufw_helper" ]] || fail 'DINX GUFW launcher is missing or not executable'
sh -n "$gufw_helper" || fail 'DINX GUFW launcher has invalid shell syntax'
grep -Fqx 'PATH=/usr/bin:/usr/local/bin:/usr/sbin:/sbin' "$gufw_helper" || fail 'GUFW launcher does not prioritize the canonical polkit executable path'
grep -Fqx 'Name=Display Settings' "$display_launcher" || fail 'Display launcher English name is incorrect'
grep -Fqx 'Exec=dinx-wdisplays' "$display_launcher" || fail 'Display launcher does not use the persistence wrapper'

for package in file-roller galculator gapless gparted sane fwupd flatpak kolourpaint phyto pori shikane udisks2 udisks2-btrfs wdisplays; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done

for removed in gvfs gvfs-gphoto2 gvfs-mtp gvfs-smb partitionmanager thunar thunar-archive-plugin thunar-volman tumbler; do
  if grep -Fqx "    - $removed" "$profile"; then
    fail "removed storage package remains in profile: $removed"
  fi
done
if grep -Fqx '    - strawberry' "$profile"; then
  fail 'Strawberry remains in the DINX profile'
fi
gapless_recipe="$root/distro/packages/gapless/PKGBUILD"
gapless_source="$root/distro/packages/gapless/source.env"
source "$gapless_source"
[[ "$GAPLESS_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || fail "invalid Gapless version: $GAPLESS_VERSION"
[[ "$GAPLESS_SOURCE_URL" == *"/g4music-${GAPLESS_VERSION}.tar.gz" ]] \
  || fail 'Gapless source URL does not match its version pin'
[[ "$GAPLESS_SOURCE_B2" =~ ^[0-9a-f]{128}$ ]] || fail 'Gapless BLAKE2 checksum is invalid'
grep -Fq 'pkgver="$GAPLESS_VERSION"' "$gapless_recipe" \
  || fail 'Gapless package version is not wired to source.env'
grep -Fq '"$GAPLESS_SOURCE_URL"' "$gapless_recipe" \
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
grep -Fqx 'Name=Firewall' "$gufw_override" || fail 'Gufw English desktop name is missing'
grep -Fqx 'Name[pt_BR]=Firewall' "$gufw_override" || fail 'Gufw Portuguese desktop name is missing'
grep -Fqx 'TryExec=/usr/local/libexec/dinx-gufw' "$gufw_override" || fail 'Gufw override does not resolve its DINX launcher'
grep -Fq 'bluetoothctl list' "$bluetooth_helper" || fail 'Bluetooth launcher does not detect available controllers'
grep -Fq 'exec blueman-manager' "$bluetooth_helper" || fail 'Bluetooth launcher does not open Blueman when a controller exists'
grep -Fqx 'Exec=/usr/local/libexec/dinx-gufw' "$gufw_override" || fail 'Gufw override does not use the path-safe DINX launcher'
grep -Fqx 'Icon=gufw' "$gufw_override" || fail 'Gufw override icon is missing'
grep -Fqx 'Name=Process Manager' "$qps_override" || fail 'Qps English desktop name is missing'
grep -Fqx 'Name[pt_BR]=Processos' "$qps_override" || fail 'Qps Portuguese desktop name is missing'
grep -Fqx 'TryExec=qps' "$qps_override" || fail 'Qps override does not resolve the installed binary'
grep -Fqx 'Exec=qps' "$qps_override" || fail 'Qps override command is missing'
grep -Fqx 'Icon=qps' "$qps_override" || fail 'Qps override icon is missing'
grep -Fqx 'Name=Traffic Monitor' "$opensnitch_override" || fail 'OpenSnitch English desktop name is missing'
grep -Fqx 'Name[pt_BR]=Monitor de Tráfego' "$opensnitch_override" || fail 'OpenSnitch Portuguese desktop name is missing'
grep -Fqx 'Exec=opensnitch-ui' "$opensnitch_override" || fail 'OpenSnitch override command is incorrect'
grep -Fqx 'Icon=opensnitch-ui' "$opensnitch_override" || fail 'OpenSnitch override icon is missing'
grep -Fqx 'Categories=System;Security;Monitor;' "$opensnitch_override" || fail 'OpenSnitch launcher must remain in one menu category'
grep -Fqx 'X-GNOME-Autostart-enabled=true' "$opensnitch_override" || fail 'OpenSnitch upstream autostart behavior is missing'
grep -Fqx 'X-GNOME-Autostart-Delay=3' "$opensnitch_override" || fail 'OpenSnitch upstream autostart delay is missing'
while IFS='|' read -r desktop_id english portuguese command; do
  desktop="$local_apps/$desktop_id"
  [[ -f "$desktop" ]] || fail "missing localized desktop override: $desktop_id"
  grep -Fqx "Name=$english" "$desktop" || fail "$desktop_id English desktop name is incorrect"
  grep -Fqx "Name[pt_BR]=$portuguese" "$desktop" || fail "$desktop_id Portuguese desktop name is incorrect"
  grep -Fqx "Exec=$command" "$desktop" || fail "$desktop_id launch command is incorrect"
done <<'EOF'
org.aqueous.Dome.desktop|System Monitor|Monitor do Sistema|dome
org.aqueous.Phyto.desktop|Files|Arquivos|phyto %u
com.shellyorg.shelly.desktop|Software & Updates|Aplicações e Updates|/usr/bin/shelly-ui %u
galculator.desktop|Calculator|Calculadora|galculator
gparted.desktop|Partition Editor|Particionador|/usr/bin/gparted %f
org.kde.kolourpaint.desktop|Drawing|Desenho|kolourpaint %u
swayimg.desktop|Image Viewer|Visualizador de Imagens|swayimg %F
org.pwmt.zathura.desktop|PDF Reader|Leitor de PDF|zathura %U
com.github.neithern.g4music.desktop|Music Player|Tocador de Música|g4music %U
vlc.desktop|Media Player|Tocador de Mídia|/usr/bin/vlc --started-from-file %U
blueman-manager.desktop|Bluetooth|Bluetooth|/usr/local/libexec/dinx-bluetooth-manager
nm-connection-editor.desktop|Network Connections|Ajustes de Rede|nm-connection-editor
com.saivert.pwvucontrol.desktop|Audio Control|Ajustes de Áudio|pwvucontrol
EOF
grep -Fqx 'NoDisplay=true' "$local_apps/swayimg.desktop" || fail 'Swayimg was exposed as a standalone menu item'
grep -Fqx 'Name=Services' "$root/distro/packages/dinitui/resources/dinitui.desktop" || fail 'DinitUI English desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Serviços' "$root/distro/packages/dinitui/resources/dinitui.desktop" || fail 'DinitUI Portuguese desktop name is incorrect'
grep -Fqx 'Name=Control Center' "$root/distro/packages/dinxpanel/resources/dinxpanel.desktop" || fail 'DINXPanel English desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Central de Controle' "$root/distro/packages/dinxpanel/resources/dinxpanel.desktop" || fail 'DINXPanel Portuguese desktop name is incorrect'
grep -Fqx 'Name=Desktop Settings' "$root/distro/packages/seafoam-settings/resources/seafoam-settings.desktop" || fail 'Seafoam Settings English desktop name is incorrect'
grep -Fqx 'Name[pt_BR]=Ajustes do Desktop' "$root/distro/packages/seafoam-settings/resources/seafoam-settings.desktop" || fail 'Seafoam Settings Portuguese desktop name is incorrect'
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
grep -Fq 'xdg-user-dir DESKTOP' "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl" || fail 'live session does not resolve the provisioned desktop directory'
grep -Fq 'installer_seed=/etc/skel/Desktop/Install\ DINX.desktop' "$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl" || fail 'live session does not seed the installer shortcut from /etc/skel'
installer_helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-installer"
[[ -x "$installer_helper" ]] || fail 'DINX installer helper is missing or not executable'
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
if grep -Eiq 'Install Artix|Instalar Artix|^(Exec|TryExec)=' "$calamares_launcher"; then
  fail 'Calamares desktop-ID mask retains an Artix identity or executable'
fi
artix_launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/applications/artix-installer.desktop"
[[ ! -e "$artix_launcher" ]] || fail 'live ISO overlay ships the redundant Artix installer launcher'
if grep -Fqx 'Hidden=true' "$dinx_installer" || grep -Fqx 'NoDisplay=true' "$dinx_installer"; then
  fail 'DINX installer shortcut is hidden'
fi
for override in org.aqueous.Dome.desktop org.aqueous.Phyto.desktop com.shellyorg.shelly.desktop galculator.desktop gparted.desktop org.kde.kolourpaint.desktop swayimg.desktop org.pwmt.zathura.desktop com.github.neithern.g4music.desktop vlc.desktop blueman-manager.desktop nm-connection-editor.desktop com.saivert.pwvucontrol.desktop; do
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
grep -Fqx '  usr/bin/kolourpaint' "$iso_check" || fail 'ISO payload is missing kolourpaint'
grep -Fqx '  usr/bin/phyto' "$iso_check" || fail 'ISO payload is missing Phyto'
grep -Fqx '  usr/bin/pori' "$iso_check" || fail 'ISO payload is missing Pori'
grep -Fqx '  usr/bin/g4music' "$iso_check" || fail 'ISO payload is missing Gapless'
grep -Fqx '  usr/bin/galculator' "$iso_check" || fail 'ISO payload is missing Galculator'
grep -Fqx '  usr/share/flatpak/remotes.d/flathub.flatpakrepo' "$iso_check" || fail 'ISO payload is missing the Flatpak source descriptor'
grep -Fqx '  usr/share/applications/org.kde.kolourpaint.desktop' "$iso_check" || fail 'ISO payload is missing the KolourPaint desktop entry'
grep -Fqx '  usr/share/applications/com.pori.app.desktop' "$iso_check" || fail 'ISO payload is missing the Pori desktop entry'
grep -Fqx '  usr/share/applications/org.aqueous.Phyto.desktop' "$iso_check" || fail 'ISO payload is missing the Phyto desktop entry'
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
grep -Fqx '  usr/local/share/applications/gufw.desktop' "$iso_check" || fail 'ISO payload is missing the localized Gufw desktop override'
grep -Fqx '  usr/local/share/applications/qps.desktop' "$iso_check" || fail 'ISO payload is missing the localized Qps desktop override'
grep -Fqx '  usr/local/share/applications/opensnitch_ui.desktop' "$iso_check" || fail 'ISO payload is missing the localized OpenSnitch desktop override'
if grep -Fq 'strawberry' "$mimeapps"; then
  fail 'Strawberry remains in the audio handler defaults'
fi
for mime in audio/mpeg audio/x-mpeg audio/x-mp3 audio/ogg audio/x-vorbis audio/x-vorbis+ogg audio/x-opus+ogg audio/flac audio/x-flac audio/wav audio/x-wav; do
  grep -Fqx "$mime=com.github.neithern.g4music.desktop;" "$mimeapps" || fail "Gapless is not the default audio handler for $mime"
done
grep -Fqx 'image/png=swayimg.desktop;' "$mimeapps" || fail 'Swayimg is no longer the default image viewer'
grep -Fqx 'inode/directory=org.aqueous.Phyto.desktop;' "$mimeapps" || fail 'Phyto is no longer the default directory handler'
for mime in application/zip application/x-7z-compressed application/vnd.rar application/x-rar application/x-tar application/gzip application/x-gzip application/x-bzip2 application/x-xz application/zstd; do
  grep -Fqx "$mime=org.gnome.FileRoller.desktop;" "$mimeapps" || fail "File Roller is not the default archive handler for $mime"
done

printf 'desktop_packages_contract calculator=galculator gapless=true codecs=gstreamer-base+good strawberry=false bilingual_launchers=true artix_alias_absent=true calamares_package_launcher_masked=true dinx_installer_visible=true installer_prerequisites_declared=true firewall=localized process_manager=localized traffic_monitor=localized sane=true fwupd=true flatpak=true kolourpaint=true phyto=true pori=true archive_tool=file-roller partition_editor=gparted display_tools=wdisplays+shikane ntfs_backend=udisks2 image_viewer=swayimg directory_handler=phyto\n'
