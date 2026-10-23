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

for package in file-roller gparted sane fwupd flatpak kolourpaint phyto pori shikane udisks2 udisks2-btrfs wdisplays; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done

for removed in gvfs gvfs-gphoto2 gvfs-mtp gvfs-smb partitionmanager thunar thunar-archive-plugin thunar-volman tumbler; do
  if grep -Fqx "    - $removed" "$profile"; then
    fail "removed storage package remains in profile: $removed"
  fi
done

grep -Fqx '  usr/bin/scanimage' "$iso_check" || fail 'ISO payload is missing scanimage'
grep -Fqx '  usr/bin/fwupdmgr' "$iso_check" || fail 'ISO payload is missing fwupdmgr'
grep -Fqx '  usr/bin/flatpak' "$iso_check" || fail 'ISO payload is missing flatpak'
grep -Fqx '  usr/bin/kolourpaint' "$iso_check" || fail 'ISO payload is missing kolourpaint'
grep -Fqx '  usr/bin/phyto' "$iso_check" || fail 'ISO payload is missing Phyto'
grep -Fqx '  usr/bin/pori' "$iso_check" || fail 'ISO payload is missing Pori'
grep -Fqx '  usr/share/flatpak/remotes.d/flathub.flatpakrepo' "$iso_check" || fail 'ISO payload is missing the Flatpak source descriptor'
grep -Fqx '  usr/share/applications/org.kde.kolourpaint.desktop' "$iso_check" || fail 'ISO payload is missing the KolourPaint desktop entry'
grep -Fqx '  usr/share/applications/com.pori.app.desktop' "$iso_check" || fail 'ISO payload is missing the Pori desktop entry'
grep -Fqx '  usr/share/applications/org.aqueous.Phyto.desktop' "$iso_check" || fail 'ISO payload is missing the Phyto desktop entry'
grep -Fqx '  usr/bin/file-roller' "$iso_check" || fail 'ISO payload is missing File Roller'
grep -Fqx '  usr/bin/gparted' "$iso_check" || fail 'ISO payload is missing GParted'
grep -Fqx '  usr/bin/shikane' "$iso_check" || fail 'ISO payload is missing Shikane'
grep -Fqx '  usr/bin/shikanectl' "$iso_check" || fail 'ISO payload is missing shikanectl'
grep -Fqx '  usr/bin/wdisplays' "$iso_check" || fail 'ISO payload is missing wdisplays'
grep -Fqx '  usr/share/applications/org.gnome.FileRoller.desktop' "$iso_check" || fail 'ISO payload is missing the File Roller desktop entry'
grep -Fqx '  usr/share/applications/gparted.desktop' "$iso_check" || fail 'ISO payload is missing the GParted desktop entry'
grep -Fqx '  usr/share/applications/network.cycles.wdisplays.desktop' "$iso_check" || fail 'ISO payload is missing the wdisplays desktop entry'
grep -Fqx 'image/png=swayimg.desktop;' "$mimeapps" || fail 'Swayimg is no longer the default image viewer'
grep -Fqx 'inode/directory=org.aqueous.Phyto.desktop;' "$mimeapps" || fail 'Phyto is no longer the default directory handler'

printf 'desktop_packages_contract sane=true fwupd=true flatpak=true kolourpaint=true phyto=true pori=true archive_tool=file-roller partition_editor=gparted display_tools=wdisplays+shikane ntfs_backend=udisks2 image_viewer=swayimg directory_handler=phyto\n'
