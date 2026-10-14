#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'check-iso-content: %s\n' "$*" >&2
  exit 1
}

iso_path=${1:-}
[[ -n "$iso_path" ]] || fail "usage: $0 ISO"
[[ -f "$iso_path" ]] || fail "ISO not found: $iso_path"

for command in mktemp rm xorriso unsquashfs grep; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /LiveOS/rootfs.img "$tmp_dir/rootfs.img" \
  >/dev/null

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /LiveOS/livefs.img "$tmp_dir/livefs.img" \
  >/dev/null

manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/rootfs.img")
livefs_manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/livefs.img")

required_paths=(
  etc/calamares/branding/dinx/branding.desc
  etc/calamares/branding/dinx/stylesheet.qss
  etc/calamares/modules/packages.conf
  etc/calamares/modules/partition.conf
  etc/calamares/modules/postcfg.conf
  etc/calamares/modules/services-artix.conf
  etc/calamares/modules/unpackfs.conf
  etc/calamares/modules/users.conf
  etc/calamares/modules/welcome.conf
  etc/calamares/settings.conf
  etc/dinit.d/greetd
  etc/dinit.d/root-ro
  etc/greetd/regreet.toml
  etc/mango/dinx.conf
  etc/mango/greeter.conf
  etc/profile.d/dinx.sh
  etc/skel/.bash_profile
  etc/skel/.bashrc
  usr/bin/foot
  usr/local/bin/dinx-terminal
  usr/share/applications/dinx-terminal-fallback.desktop
  usr/bin/udisksctl
  usr/lib/gvfs-udisks2-volume-monitor
  usr/lib/udisks2/udisksd
  usr/share/applications/thunar.desktop
  usr/share/dbus-1/services/org.gtk.vfs.UDisks2VolumeMonitor.service
  usr/share/dbus-1/system-services/org.freedesktop.UDisks2.service
  usr/bin/mango
  usr/bin/mmsg
  usr/bin/noctalia
  usr/bin/noctty
  usr/bin/nocted
  usr/share/applications/com.noctty.NOCTTY.desktop
  usr/share/applications/com.noctty.NoctEd.desktop
  usr/share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg
  usr/share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg
  usr/share/nocted/language-specs/zig.lang
  usr/share/nocted/language-specs/svelte.lang
  usr/share/nocted/language-specs/kof.lang
  usr/share/nocted/styles/nocted-dark.xml
  usr/bin/calamares
  usr/bin/partitionmanager
  usr/share/wayland-sessions/mango.desktop
  usr/bin/regreet
  usr/local/libexec/dinx-regreet
  usr/local/libexec/dinx-mango
  usr/share/applications/dinx-installer.desktop
  usr/share/applications/org.kde.partitionmanager.desktop
  usr/share/grub/themes/artix/theme.txt
  usr/share/xdg-desktop-portal/mango-portals.conf
)

for path in "${required_paths[@]}"; do
  grep -Fq "/$path" <<<"$manifest" || fail "missing ISO path: $path"
done

plasma_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/xsessions/plasmax11.desktop)
grep -Fq 'Hidden=true' <<<"$plasma_session" || fail 'Plasma X11 session is not hidden from the DINX greeter'
grep -Fq 'NoDisplay=true' <<<"$plasma_session" || fail 'Plasma X11 session remains visible to the DINX greeter'

plasma_wayland_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/wayland-sessions/plasma.desktop)
grep -Fq 'Hidden=true' <<<"$plasma_wayland_session" || fail 'Plasma Wayland session is not hidden from the DINX greeter'
grep -Fq 'NoDisplay=true' <<<"$plasma_wayland_session" || fail 'Plasma Wayland session remains visible to the DINX greeter'

grub_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/grub/themes/artix/theme.txt)
grep -Fq 'DINX GRUB theme override.' <<<"$grub_theme" || fail 'DINX GRUB theme override is missing'
if grep -Eq '^[[:space:]]*(menu_pixmap_style|selected_item_pixmap_style)[[:space:]]*=' <<<"$grub_theme"; then
  fail 'DINX GRUB theme still enables opaque menu textures'
fi

regreet_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/greetd/regreet.toml)
grep -Fq 'application_prefer_dark_theme = true' <<<"$regreet_config" || fail 'ReGreet dark mode is not enabled'

noctalia_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/noctalia/config.toml)
grep -Fq 'mode = "dark"' <<<"$noctalia_config" || fail 'Noctalia dark mode is not enabled'
grep -Fq '[shell.animation]' <<<"$noctalia_config" || fail 'Noctalia animation defaults are missing'
grep -Fq 'enabled = false' <<<"$noctalia_config" || fail 'Noctalia animations are not disabled by default'
grep -Fq 'settings_window_translucent = false' <<<"$noctalia_config" || fail 'Noctalia Settings transparency is not disabled by default'
grep -Fq '[shell.panel]' <<<"$noctalia_config" || fail 'Noctalia panel defaults are missing'
grep -Fq 'transparency_mode = "solid"' <<<"$noctalia_config" || fail 'Noctalia panel transparency is not disabled by default'

mango_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/mango/dinx.conf)
grep -Fq 'tag_num=2' <<<"$mango_config" || fail 'Mango does not start with two virtual desktops'
grep -Fq 'env=TERMINAL,dinx-terminal' <<<"$mango_config" || fail 'Mango does not expose the DINX terminal contract'
grep -Fq 'source_optional=~/.config/mango/config.conf' <<<"$mango_config" || fail 'Mango user workspace override is not enabled'
grep -Fq 'exec_once=lxqt-policykit-agent' <<<"$mango_config" || fail 'Mango does not start the PolicyKit authentication agent'
grep -Fq 'exec_once=thunar --daemon' <<<"$mango_config" || fail 'Mango does not start the Thunar volume monitor'
grep -Fq 'bind=SUPER,Return,spawn,foot' <<<"$mango_config" || fail 'Mango fallback terminal shortcut is missing'
shell_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/profile.d/dinx.sh)
grep -Fq 'TERMINAL=' <<<"$shell_config" || fail 'DINX shell terminal default is missing'
grep -Fq 'EDITOR=' <<<"$shell_config" || fail 'DINX shell editor default is missing'
mimeapps_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/xdg/mimeapps.list)
grep -Fq 'inode/directory=thunar.desktop;' <<<"$mimeapps_config" || fail 'Thunar is not the default directory handler'

# Artix desktop packages may ship inert compatibility unit files; reject the init/runtime itself.
for forbidden_path in \
  etc/systemd \
  usr/lib/systemd/systemd \
  usr/bin/systemd \
  usr/bin/systemctl \
  usr/bin/xfce4-session \
  usr/bin/xfdesktop \
  usr/bin/xfwm4 \
  usr/bin/xfce4-panel \
  usr/bin/lxqt-session \
  usr/bin/lxqt-panel \
  usr/bin/lxqt-runner; do
  if forbidden_matches=$(grep -F "/$forbidden_path" <<<"$manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail "forbidden desktop/runtime payload is present: $forbidden_path"
  fi
done

mango_user_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/mango/config.conf)
grep -Fq 'tag_num=2' <<<"$mango_user_config" || fail 'Mango user workspace default is not two'

calamares_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/settings.conf)
grep -Fq 'branding: dinx' <<<"$calamares_settings" || fail 'DINX Calamares branding is not selected'
grep -Fq 'services-artix' <<<"$calamares_settings" || fail 'Calamares dinit service module is not selected'
grep -Fq 'postcfg' <<<"$calamares_settings" || fail 'Calamares dinit user-service module is not selected'
calamares_services=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/services-artix.conf)
grep -Fq 'getty@tty2' <<<"$calamares_services" || fail 'Calamares recovery TTY service is not selected'
grep -Fq 'getty@tty3' <<<"$calamares_services" || fail 'Calamares second recovery TTY service is not selected'

calamares_branding=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/branding/dinx/stylesheet.qss)
grep -Fq '#11151c' <<<"$calamares_branding" || fail 'DINX Calamares dark stylesheet is missing'

installer_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinx-installer.desktop)
grep -Fq 'Exec=pkexec calamares' <<<"$installer_desktop" || fail 'DINX installer launcher is missing'
noctty_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/com.noctty.NOCTTY.desktop)
grep -Fq 'TryExec=noctty' <<<"$noctty_desktop" || fail 'NOCTTY desktop launcher is missing'
grep -Fq 'Exec=noctty --open-uri %u' <<<"$noctty_desktop" || fail 'NOCTTY desktop command is incorrect'

nocted_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/com.noctty.NoctEd.desktop)
grep -Fq 'Exec=nocted %F' <<<"$nocted_desktop" || fail 'NoctEd desktop launcher is missing'
grep -Fq 'Icon=com.noctty.NoctEd' <<<"$nocted_desktop" || fail 'NoctEd desktop icon is missing'


grep -Fq '/usr/lib/libscenefx' <<<"$manifest" || fail 'missing Scenefx library'

livefs_required_paths=(
  etc/artools/live.conf
  etc/dinit.d/boot.d/NetworkManager
  etc/dinit.d/boot.d/artix-live
  etc/dinit.d/boot.d/greetd
  etc/dinit.d/boot.d/logind
  etc/dinit.d/boot.d/metalog
  etc/dinit.d/boot.d/pacman-init
  etc/dinit.d/boot.d/userspawn
)

for path in "${livefs_required_paths[@]}"; do
  grep -Fq "/$path" <<<"$livefs_manifest" || fail "missing livefs path: $path"
done

live_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/artools/live.conf)
grep -Fq 'AUTOLOGIN=false' <<<"$live_config" || fail 'live session autologin is not disabled'
grep -Fq 'LIVEUSER=dinx' <<<"$live_config" || fail 'live session user is not dinx'

live_passwd=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/passwd)
grep -Eq '^dinx:' <<<"$live_passwd" || fail 'live session user dinx is missing'

printf 'ISO content check passed: MangoWM with two editable desktops, static opaque Noctalia, Thunar/GVFS/UDisks2 removable-media support, dark ReGreet/Calamares, KDE Partition Manager, greetd, and dinit payloads present without systemd or a full Xfce/LXQt session.\n'
