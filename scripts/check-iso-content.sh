#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'check-iso-content: %s\n' "$*" >&2
  exit 1
}

assert_desktop_entry() {
  local path=$1 contents=$2 english=$3 portuguese=$4 command=$5
  grep -Fqx "Name=$english" <<<"$contents" || fail "$path has the wrong English launcher name"
  grep -Fqx "Name[pt_BR]=$portuguese" <<<"$contents" || fail "$path has the wrong Portuguese launcher name"
  grep -Fqx "$command" <<<"$contents" || fail "$path has the wrong launch command"
}

iso_path=${1:-}
[[ -n "$iso_path" ]] || fail "usage: $0 ISO"
[[ -f "$iso_path" ]] || fail "ISO not found: $iso_path"
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$script_dir/lib/iso-content-manifest.sh"

for command in jq mktemp rm xorriso unsquashfs grep cmp python3; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /boot/initramfs-x86_64.img "$tmp_dir/initramfs.img" \
  >/dev/null

initramfs_manifest=$(PYTHONDONTWRITEBYTECODE=1 python3 "$script_dir/initramfs_manifest.py" "$tmp_dir/initramfs.img")
for graphics_module in vmwgfx vboxvideo; do
  grep -Eq "/${graphics_module}\\.ko(\\.(zst|xz|gz))?$" <<<"$initramfs_manifest" \
    || fail "live initramfs omits the VirtualBox graphics module: $graphics_module"
done

for plymouth_path in \
  etc/plymouth/plymouthd.conf \
  usr/bin/plymouth \
  usr/bin/plymouthd \
  usr/lib/plymouth/script.so \
  usr/share/plymouth/themes/dinx/dinx.plymouth \
  usr/share/plymouth/themes/dinx/dinx.script \
  usr/share/plymouth/themes/dinx/logo.png; do
  grep -Fq "$plymouth_path" <<<"$initramfs_manifest" \
    || fail "live initramfs omits the DINX Plymouth runtime or theme: $plymouth_path"
done

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /LiveOS/rootfs.img "$tmp_dir/rootfs.img" \
  >/dev/null

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /LiveOS/livefs.img "$tmp_dir/livefs.img" \
  >/dev/null

for squashfs in "$tmp_dir/rootfs.img" "$tmp_dir/livefs.img"; do
  squashfs_stats=$(unsquashfs -no-xattrs -no-progress -s "$squashfs")
  grep -Eq 'Compression[[:space:]]+xz([[:space:]]|$)' <<<"$squashfs_stats" \
    || fail "SquashFS image is not xz-compressed: $squashfs"
  grep -Eq 'Block size[[:space:]]+1048576([[:space:]]|$)' <<<"$squashfs_stats" \
    || fail "SquashFS image does not use 1 MiB blocks: $squashfs"
done

manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/rootfs.img")
livefs_manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/livefs.img")

if grep -Fq 'squashfs-root/usr/share/applications/artix-installer.desktop' <<<"$manifest"; then
  fail 'live ISO ships an Artix installer desktop shortcut'
fi
for live_path in \
  etc/artools/live.conf \
  etc/dinit.d/dinx-live-autologin \
  etc/dinit.d/dinx-keyring-populate \
  etc/dinit.d/boot.d/greetd \
  etc/dinit.d/boot.d/dinx-live-autologin \
  etc/dinit.d/root-ro \
  etc/dinit.d/early-root-rw.target \
  usr/local/libexec/dinx-live-autologin \
  etc/polkit-1/rules.d/00-dinx-live-passwordless.rules \
  etc/issue; do
  grep -Fq "squashfs-root/$live_path" <<<"$livefs_manifest" \
    || fail "missing livefs path: $live_path"
done
live_cli_issue=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/issue)
grep -Fq 'DINX Linux' <<<"$live_cli_issue" || fail 'live CLI login banner is not branded as DINX Linux'
if grep -Eiq 'Artix' <<<"$live_cli_issue"; then
  fail 'live CLI login banner still identifies Artix'
fi
# The livefs is an overlay; greetd's service file is inherited from rootfs.
grep -Fq 'squashfs-root/etc/dinit.d/boot.d/greetd -> /etc/dinit.d/greetd' <<<"$livefs_manifest" \
  || fail 'livefs greetd boot link does not target the inherited rootfs service'

if grep -Fq '/etc/dinit.d/root-ro' <<<"$manifest" \
  || grep -Fq '/etc/dinit.d/early-root-rw.target' <<<"$manifest"; then
  fail 'live-only root remount overrides leaked into the installed rootfs'
fi
# man-db/man-pages/texinfo are builder-only; their payloads are stripped from
# the final images (see scripts/iso-tools/mksquashfs strip_documentation).
for stripped_path in \
  usr/share/man \
  usr/share/gtk-doc \
  usr/share/help \
  usr/share/info; do
  if grep -Fq "squashfs-root/$stripped_path/" <<<"$manifest" \
    || grep -Fq "squashfs-root/$stripped_path/" <<<"$livefs_manifest"; then
    fail "documentation payload survived the final squashfs: $stripped_path"
  fi
done
if grep -F 'squashfs-root/usr/share/doc/' <<<"$manifest" \
  | grep -E '^-' \
  | grep -Ev '/SOURCE$' \
  | grep -Eiv '/(COPYING|LICEN[CS]E|copyright|licencia)[^/]*$' \
  | grep -q .; then
  fail 'non-license files survived under usr/share/doc in the rootfs'
fi
live_policy_path=etc/polkit-1/rules.d/00-dinx-live-passwordless.rules
if grep -Fq "squashfs-root/$live_policy_path" <<<"$manifest"; then
  fail 'live-only Polkit authorization leaked into the installed rootfs'
fi
live_policy=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" "$live_policy_path")
grep -Fq 'subject.user === "dinx"' <<<"$live_policy" \
  || fail 'live Polkit rule is not scoped to the dinx live user'
if grep -Eq 'subject\.(active|local)' <<<"$live_policy"; then
  fail 'live Polkit rule still requires elogind session state'
fi
grep -Fq 'return polkit.Result.YES;' <<<"$live_policy" \
  || fail 'live Polkit rule does not authorize without credentials'
if grep -Eq 'auth_(admin|self)' <<<"$live_policy"; then
  fail 'live Polkit rule still requires authentication'
fi
for target in root-ro early-root-rw.target; do
  live_root_mount=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" "etc/dinit.d/$target")
  grep -Fqx 'command = /bin/true' <<<"$live_root_mount" \
    || fail "livefs does not bypass the overlay remount in $target"
done
live_conf=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/artools/live.conf)
grep -Eq '^AUTOLOGIN=true$' <<<"$live_conf" \
  || fail 'livefs does not enable DINX autologin'
live_autologin=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/local/libexec/dinx-live-autologin)
grep -Fq 'install -d -o dinx -g dinx -m 0700 /run/dinx-session' <<<"$live_autologin" \
  || fail 'livefs autologin does not provision the private session runtime dir'
live_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/local/libexec/dinx-live-session)
grep -Fq 'exec /usr/bin/openvt -c 7 -s -f -e -- runuser -u dinx' <<<"$live_session" \
  || fail 'livefs session does not acquire and activate dedicated VT 7'
grep -Fq 'runuser -u dinx' <<<"$live_session" \
  || fail 'livefs session does not start as the dinx user'
grep -Fq 'dbus-run-session /usr/local/libexec/dinx-river-session' <<<"$live_session" \
  || fail 'livefs session does not start the River/KWM/Morghulis wrapper'
live_greetd_unit=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/greetd)
grep -Fq 'command = /bin/true' <<<"$live_greetd_unit" \
  || fail 'livefs does not shadow greetd with a no-op unit'
! grep -Fq '/usr/bin/pacman-key' <<<"$live_autologin" \
  || fail 'live greeter setup runs keyring operations before greetd'
live_autologin_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/dinx-live-autologin)
grep -Fq 'command = /usr/local/libexec/dinx-live-autologin' <<<"$live_autologin_service" \
  || fail 'livefs autologin service command is incorrect'
grep -Fqx 'depends-on = local.target' <<<"$live_autologin_service" \
  || fail 'livefs autologin service does not depend on local.target'
grep -Fqx 'depends-on = artix-live' <<<"$live_autologin_service" \
  || fail 'livefs autologin service does not depend on artix-live'
! grep -Fqx 'depends-on = pacman-init' <<<"$live_autologin_service" \
  || fail 'live greeter setup must not depend on keyring population'
grep -Fqx 'waits-for = firewalld' <<<"$live_autologin_service" \
  || fail 'live autologin does not wait for the Firewalld startup attempt'
! grep -Fqx 'depends-on = local.target artix-live' <<<"$live_autologin_service" \
  || fail 'livefs autologin service combines dependencies into one unresolved service name'
live_greetd_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/greetd)
grep -Fqx 'type = scripted' <<<"$live_greetd_service" \
  || fail 'live greetd shadow is not a scripted no-op service'
grep -Fqx 'command = /bin/true' <<<"$live_greetd_service" \
  || fail 'live greetd shadow does not disable the display manager'
live_session_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/dinx-live-session)
grep -Fqx 'type = process' <<<"$live_session_service" \
  || fail 'live session service is not a process service'
grep -Fqx 'command = /usr/local/libexec/dinx-live-session' <<<"$live_session_service" \
  || fail 'live session service command is incorrect'
grep -Fqx 'depends-on = dinx-live-autologin' <<<"$live_session_service" \
  || fail 'live session service does not wait for live boot preparation'
grep -Fqx 'depends-on = seatd' <<<"$live_session_service" \
  || fail 'live session service does not depend on seatd'
grep -Fqx 'restart = true' <<<"$live_session_service" \
  || fail 'live session service does not restart after an unexpected exit'
root_greetd_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/dinit.d/greetd)
grep -Eq '^command[[:space:]]*=[[:space:]]*/usr/bin/greetd$' <<<"$root_greetd_service" \
  || fail 'installed greetd service command is incorrect'
grep -Eq '^smooth-recovery[[:space:]]*=[[:space:]]*true$' <<<"$root_greetd_service" \
  || fail 'installed greetd service does not preserve smooth recovery'
grep -Eq '^restart-delay[[:space:]]*=[[:space:]]*7$' <<<"$root_greetd_service" \
  || fail 'installed greetd service does not wait for greeter teardown'
grep -Eq '^depends-on[[:space:]]*=[[:space:]]*login\.target$' <<<"$root_greetd_service" \
  || fail 'installed greetd service does not use the login target'
if grep -Fq 'dinx-live-autologin' <<<"$root_greetd_service"; then
  fail 'live-only autologin dependency leaked into the installed greetd service'
fi
keyring_bootstrap_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/dinit.d/dinx-keyring-bootstrap)
grep -Fqx 'command = /usr/local/libexec/dinx-keyring-bootstrap' <<<"$keyring_bootstrap_service" \
  || fail 'installed DINX keyring bootstrap command is incorrect'
! grep -Fq 'stop-command =' <<<"$keyring_bootstrap_service" \
  || fail 'installed DINX keyring bootstrap still discards its persistent keyring during shutdown'
grep -Fqx 'depends-on = local.target' <<<"$keyring_bootstrap_service" \
  || fail 'installed DINX keyring bootstrap does not wait for local.target'
keyring_populate_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/dinit.d/dinx-keyring-populate)
grep -Fqx 'command = /usr/local/libexec/dinx-keyring-populate' <<<"$keyring_populate_service" \
  || fail 'installed DINX keyring population command is incorrect'
grep -Fqx 'depends-on = dinx-keyring-bootstrap' <<<"$keyring_populate_service" \
  || fail 'installed DINX keyring population does not wait for its keyring bootstrap'
live_keyring_populate_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/dinx-keyring-populate)
grep -Fqx 'command = /usr/local/libexec/dinx-keyring-populate' <<<"$live_keyring_populate_service" \
  || fail 'live DINX keyring population command is incorrect'
grep -Fqx 'depends-on = pacman-init' <<<"$live_keyring_populate_service" \
  || fail 'live DINX keyring population does not wait for pacman-init'


required_paths=(
  etc/calamares/branding/dinx/branding.desc
  etc/calamares/branding/dinx/notesqml.qml
  etc/calamares/branding/dinx/stylesheet.qss
  etc/calamares/modules/notesqml.conf
  etc/calamares/modules/packages.conf
  etc/calamares/modules/mount.conf
  etc/calamares/modules/bootloader.conf
  etc/calamares/modules/postcfg.conf
  etc/calamares/modules/services-artix.conf
  etc/calamares/modules/unpackfs.conf
  etc/calamares/modules/users.conf
  etc/calamares/modules/welcome.conf
  etc/calamares/settings.conf
  etc/default/grub.d/40-dinx-windows.cfg
  etc/dinit.d/greetd
  etc/dinit.d/turnstiled
  etc/dinit.d/boot.d/turnstiled
  etc/pam.d/greetd
  etc/pam.d/turnstiled
  usr/bin/turnstiled
  usr/lib/security/pam_turnstile.so
  usr/share/licenses/turnstile/COPYING.md
  etc/turnstile/turnstiled.conf
  etc/dinit.d/dinx-plymouth-quit
  etc/dinit.d/boot.d/dinx-plymouth-quit
  etc/dinit.d/dinx-keyring-bootstrap
  etc/dinit.d/dinx-keyring-populate
  etc/dinit.d/boot.d/dinx-keyring-populate
  usr/local/libexec/dinx-keyring-bootstrap
  usr/local/libexec/dinx-keyring-populate
  usr/share/pacman/keyrings/dinx.gpg
  usr/share/pacman/keyrings/dinx-trusted
  usr/share/pacman/keyrings/dinx-revoked
  etc/pacman.d/dinx-mirrorlist
  etc/plymouth/plymouthd.conf
  usr/bin/plymouth
  usr/bin/plymouthd
  usr/lib/plymouth/script.so
  usr/local/libexec/dinx-plymouth-quit
  usr/share/plymouth/themes/dinx/dinx.plymouth
  usr/share/plymouth/themes/dinx/dinx.script
  usr/share/plymouth/themes/dinx/logo.png
  usr/bin/unsquashfs
  etc/greetd/config.toml
  usr/bin/agreety
  usr/local/libexec/dinx-graphics-environment.sh
  usr/bin/reboot
  usr/bin/poweroff
  usr/bin/dinitui
  usr/bin/dinxpanel
  usr/share/applications/dinitui.desktop
  usr/share/applications/dinxpanel.desktop
  usr/share/icons/hicolor/scalable/apps/org.dinx.DinitUI.svg
  usr/share/applications/dinx-lock.desktop
  usr/share/icons/hicolor/scalable/apps/org.dinx.DinxPanel.svg
  usr/share/licenses/dinitui/LICENSE
  usr/share/licenses/dinxpanel/LICENSE
  usr/local/libexec/dinx-gaming
  usr/bin/setsid
  usr/local/bin/dinx-alpha7-hardware-report
  usr/local/bin/dinx-doctor
  usr/share/wayland-sessions/dinx-gaming.desktop
  usr/bin/flatpak
  usr/bin/fwupdmgr
  usr/bin/scanimage
  etc/dinit.d/bluetoothd
  etc/profile.d/dinx.sh
  etc/default/useradd
  etc/fish/config.fish
  etc/skel/.bash_profile
  etc/skel/.config/gtk-3.0/settings.ini
  etc/skel/.config/gtk-4.0/settings.ini
  etc/skel/.config/qt6ct/qt6ct.conf
  etc/skel/.config/qt6ct/colors/DINX.conf
  etc/skel/.config/swayimg/init.lua
  etc/skel/.bashrc
  etc/skel/.config/shikane/config.toml
  "etc/skel/Desktop/Install DINX.desktop"
  usr/share/themes/DINX/gtk-3.0/gtk.css
  usr/share/themes/DINX/gtk-4.0/gtk.css
  usr/share/themes/DINX/index.theme
  usr/share/themes/DINX/gtk-3.0/gtk-dark.css
  usr/share/themes/DINX/gtk-4.0/gtk-dark.css
  usr/bin/qt6ct
  usr/share/themes/adw-gtk3/gtk-3.0/gtk.css
  usr/share/themes/adw-gtk3/gtk-4.0/gtk.css
  usr/bin/xdg-user-dirs-update
  usr/local/libexec/dinx-river-session
  usr/local/libexec/dinx-river-init
  usr/local/libexec/dinx-morghulis-first-run
  usr/local/libexec/dinx-sync-session-theme
  usr/local/libexec/dinx-set-theme
  usr/local/libexec/dinx-pcmanfm-desktop
  usr/local/libexec/dinx-qt6ct-palette-seed
  usr/bin/river
  usr/bin/kwm
  usr/bin/morghulis
  usr/bin/pcmanfm
  usr/local/libexec/dinx-graphics-profile
  usr/lib/dri/virtio_gpu_dri.so
  usr/lib/dri/vmwgfx_dri.so
  usr/share/dinx/theme/DINX.json
  usr/bin/pori
  usr/local/libexec/pori-mount-service
  usr/bin/file-roller
  usr/bin/missioncenter
  usr/share/applications/io.missioncenter.MissionCenter.desktop
  usr/share/metainfo/io.missioncenter.MissionCenter.metainfo.xml
  usr/share/licenses/mission-center/COPYING
  usr/bin/gparted
  usr/share/polkit-1/actions/org.gnome.gparted.policy
  usr/bin/shikane
  usr/bin/shikanectl
  usr/bin/wdisplays
  usr/bin/fish
  usr/bin/nano
  usr/bin/ffmpeg
  usr/bin/btop
  usr/bin/dialog
  usr/bin/fzf
  usr/bin/sftp
  usr/bin/sqlite3
  usr/bin/tmux
  usr/bin/watch
  usr/bin/whiptail
  usr/share/kio/servicemenus/deettyhere.desktop
  usr/lib/ssh/sftp-server
  usr/bin/nvtop
  usr/bin/pwvucontrol
  usr/bin/blueman-manager
  usr/bin/bluetoothctl
  usr/bin/upower
  usr/bin/inxi
  usr/bin/lspci
  usr/bin/lsusb
  usr/bin/git
  usr/bin/curl
  usr/bin/less
  usr/bin/jq
  usr/bin/rsync
  usr/bin/nm-connection-editor
  usr/bin/swayimg
  usr/bin/haruna
  usr/bin/g4music
  usr/bin/galculator
  usr/bin/paru
  usr/bin/checkupdates
  usr/lib/firmware/amdgpu/cyan_skillfish2_pfp.bin.zst
  usr/share/vulkan/icd.d/radeon_icd.json
  usr/share/vulkan/icd.d/lvp_icd.json
  usr/lib/libvulkan_lvp.so
  usr/bin/vulkaninfo
  usr/lib/dri/virtio_gpu_dri.so
  usr/lib/dri/vmwgfx_dri.so
  etc/paru.conf
  usr/share/flatpak/remotes.d/flathub.flatpakrepo
  usr/bin/firefox
  usr/lib/firefox/firefox
  usr/lib/firefox/distribution/policies.json
  usr/share/applications/firefox.desktop
  usr/share/applications/org.kde.haruna.desktop
  usr/share/licenses/haruna/LICENSE
  usr/share/applications/com.github.neithern.g4music.desktop
  usr/share/applications/galculator.desktop
  usr/share/licenses/gapless/COPYING
  usr/share/dbus-1/services/com.github.neithern.g4music.service
  usr/share/glib-2.0/schemas/com.github.neithern.g4music.gschema.xml
  usr/share/glib-2.0/schemas/com.arkye.morghulis.gschema.xml
  usr/share/glib-2.0/schemas/gschemas.compiled
  usr/share/applications/swayimg.desktop
  usr/bin/firewall-cmd
  usr/bin/firewall-offline-cmd
  usr/bin/firewalld
  usr/bin/firewall-config
  usr/share/applications/firewall-config.desktop
  usr/share/polkit-1/actions/org.fedoraproject.FirewallD1.desktop.policy.choice
  etc/dinit.d/firewalld
  usr/bin/wl-copy
  usr/bin/wl-paste
  usr/lib/bluetooth/bluetoothd
  usr/share/applications/com.saivert.pwvucontrol.desktop
  usr/lib/libghostty-vt.so.0
  usr/include/ghostty/vt.h
  usr/share/licenses/ghostty-vt-runtime/LICENSE
  usr/bin/deetty
  usr/bin/dintor
  usr/share/applications/org.dinx.Deetty.desktop
  usr/share/applications/org.dinx.Dintor.desktop
  usr/share/icons/hicolor/scalable/apps/org.dinx.Deetty.svg
  usr/share/icons/hicolor/scalable/apps/org.dinx.Dintor.svg
  usr/share/kio/servicemenus/deettyhere.desktop
  usr/share/dintor/language-specs/zig.lang
  usr/share/dintor/language-specs/svelte.lang
  usr/share/dintor/language-specs/kof.lang
  usr/share/dintor/styles/dintor-dark.xml
  usr/share/dintor/styles/dintor-light.xml
  usr/bin/calamares
  usr/share/polkit-1/actions/io.calamares.calamares.policy
  usr/bin/dconf
  usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
  usr/share/wayland-sessions/dinx-river-kwm-morghulis.desktop
  usr/share/wayland-sessions/dinx-river-kwm-redbean.desktop
  usr/local/libexec/dinx-redbean-session
  usr/bin/redbean
  usr/bin/tuigreet
  usr/local/libexec/dinx-idle
  usr/local/libexec/dinx-lock
  usr/bin/dbus-send
  usr/bin/lxqt-policykit-agent
  usr/bin/pkexec
  usr/bin/zenity
  usr/bin/pgrep
  usr/bin/timeout
  usr/local/libexec/dinx-installer
  usr/local/libexec/dinx-gparted
  usr/local/libexec/dinx-approve-desktop-launcher
  usr/bin/python3
  usr/bin/ps
  usr/share/applications/dinx-installer.desktop
  usr/share/applications/calamares.desktop
  "etc/skel/Desktop/Install DINX.desktop"
  usr/local/bin/dinx-save-shikane-profile
  usr/local/bin/dinx-wdisplays
  usr/bin/brightnessctl
  usr/bin/swayidle
  usr/bin/swaylock
  usr/bin/wlopm
  usr/share/applications/com.pori.app.desktop
  usr/share/applications/pcmanfm.desktop
  usr/share/applications/org.gnome.FileRoller.desktop
  usr/local/share/applications/org.gnome.FileRoller.desktop
  usr/local/share/applications/pcmanfm.desktop
  usr/local/share/applications/galculator.desktop
  usr/local/share/applications/gparted.desktop
  usr/local/share/applications/swayimg.desktop
  usr/local/share/applications/com.github.neithern.g4music.desktop
  usr/local/share/applications/org.kde.haruna.desktop
  usr/local/share/applications/blueman-manager.desktop
  usr/local/libexec/dinx-bluetooth-manager
  usr/local/share/applications/nm-connection-editor.desktop
  usr/local/share/applications/com.saivert.pwvucontrol.desktop
  usr/local/share/applications/btop.desktop
  usr/local/share/applications/nvtop.desktop
  usr/local/share/applications/mimeinfo.cache
  usr/share/applications/gparted.desktop
  usr/share/applications/network.cycles.wdisplays.desktop
  usr/share/grub/themes/artix/theme.txt
  etc/calamares/branding/dinx/dinx.svg
  etc/calamares/branding/dinx/dinx-ray-mark.svg
  etc/calamares/branding/dinx/dinx-emblem.png
  usr/lib/calamares/modules/services-artix/main.py
  usr/lib/calamares/modules/services-artix/module.desc
  usr/lib/calamares/modules/postcfg/main.py
  usr/lib/calamares/modules/postcfg/module.desc
  usr/share/dinx/branding/dinx-ray-mark.txt
  usr/share/fonts/dinx-noto-latin/NotoSans-Regular.ttf
  usr/share/fonts/dinx-noto-latin/NotoSans-Bold.ttf
  usr/share/fonts/dinx-noto-latin/NotoSans-Italic.ttf
  usr/share/fonts/dinx-noto-latin/NotoSans-BoldItalic.ttf
  usr/share/fonts/dinx-noto-latin/NotoSansMono-Regular.ttf
  usr/share/grub/themes/artix/logo.png
  usr/share/themes/Orchis-Light/index.theme
  usr/share/themes/Orchis-Dark/index.theme
  usr/share/themes/Orchis-Square-Light/index.theme
  usr/share/themes/Orchis-Square-Dark/index.theme
  usr/share/themes/Skeuos-Blue-Light/index.theme
  usr/share/themes/Skeuos-Blue-Dark/index.theme
  usr/share/themes/Skeuos-Blue-Light-Square/index.theme
  usr/share/themes/Skeuos-Blue-Dark-Square/index.theme
  usr/share/themes/Fluent-Light/index.theme
  usr/share/themes/Fluent-Dark/index.theme
  usr/share/themes/Fluent-Square-Light/index.theme
  usr/share/themes/Fluent-Square-Dark/index.theme
  usr/share/themes/Jasper-Light/index.theme
  usr/share/themes/Jasper-Dark/index.theme
  usr/share/themes/Jasper-Square-Light/index.theme
  usr/share/themes/Jasper-Square-Dark/index.theme
)

for path in "${required_paths[@]}"; do
  iso_manifest_contains_path "$path" <<<"$manifest" \
    || fail "missing ISO path (exact path required): $path"
done
for image_manifest in "$manifest" "$livefs_manifest"; do
  for shadow_wrapper in usr/local/bin/gparted usr/local/bin/firewall-config; do
    if iso_manifest_contains_path "$shadow_wrapper" <<<"$image_manifest"; then
      fail "local wrapper shadows an upstream Polkit-aware application: $shadow_wrapper"
    fi
  done
  for unused_path in \
    etc/skel/.config/dinx/theme.json \
    usr/share/dinx/branding/dinx-linux-logo.svg \
    usr/share/dinx/branding/dinx-ray-mark.svg; do
    if grep -Fq "/$unused_path" <<<"$image_manifest"; then
      fail "unreferenced branding/config payload remains in the ISO: $unused_path"
    fi
  done
  unused_calamares_matches=$(
    grep -E 'squashfs-root/(etc/calamares-config-switcher\.conf|usr/bin/calamares-config-switcher|usr/share/applications/calamares-config-switcher\.desktop|usr/lib/calamares/modules/basestrap/[^/[:space:]]+|usr/share/calamares/modules/basestrap\.conf|usr/share/calamares/branding/(artix|artix-next)/[^/[:space:]]+)' \
      <<<"$image_manifest" | grep -v '^d' || true
  )
  if [[ -n "$unused_calamares_matches" ]]; then
    printf '%s\n' "$unused_calamares_matches" >&2
    fail 'unused Artix Calamares branding, switcher or basestrap payload remains in the ISO'
  fi
done
grep -Eq '/var/lib/pacman/local/dinx-noto-latin-[^/]*/' <<<"$manifest" \
  || fail 'DINX Noto Latin provider package metadata is missing from the installed rootfs'
grep -Eq '/var/lib/pacman/local/dinx-gtk-themes-[^/]*/' <<<"$manifest" \
  || fail 'DINX GTK themes package metadata is missing from the installed rootfs'
iso_profile_roster="$script_dir/../distro/iso/iso-profiles/dinx/profile.yaml"
[[ -r "$iso_profile_roster" ]] || fail 'DINX ISO profile roster is not readable'
for roster_package in river kwm kwim greetd-agreety greetd; do
  grep -Eq "^[[:space:]]+- ${roster_package}([[:space:]]|$)" "$iso_profile_roster" \
    || fail "the River/KWM session roster entry is missing from the ISO profile: $roster_package"
done
for retired_roster_package in aqueous pearl dinx-pearl-themes matugen; do
  if grep -Eq "^[[:space:]]+- ${retired_roster_package}([[:space:]]|$)" "$iso_profile_roster"; then
    printf '%s\n' "retired roster entry: $retired_roster_package" >&2
    fail "retired Aqueous/Pearl package remains in the ISO profile roster: $retired_roster_package"
  fi
done
for image_manifest in "$manifest" "$livefs_manifest"; do
  if grep -Eq '/var/lib/pacman/local/noto-fonts-[0-9][^/]*/' <<<"$image_manifest"; then
    fail 'full upstream Noto package metadata is present despite the DINX subset provider'
  fi
done
for package in haruna firefox; do
  grep -Eq "/var/lib/pacman/local/${package}-[^/]*/" <<<"$manifest" \
    || fail "required desktop application is not installed in rootfs: $package"
done
for retired_app in wordcraft gridcraft deckcraft pdfcraft onlyoffice zrythm impasto blockbench transit zenkai shelly qps glances sane seafoam-settings phyto dome; do
  if grep -Eq "/var/lib/pacman/local/${retired_app}-[^/]*/" <<<"$manifest"; then
    fail "retired office/graphics package metadata remains in rootfs: $retired_app"
  fi
done
for disabled_creative_package in pixelorama paintfe blender godot krita inkscape patchy audionaut; do
  if grep -Eq "/var/lib/pacman/local/${disabled_creative_package}-[^/]*/" <<<"$manifest"; then
    fail "disabled NEXT creative package metadata remains in rootfs: $disabled_creative_package"
  fi
done
grep -Eq '/var/lib/pacman/local/papirus-icon-theme-[^/]*/' <<<"$manifest" \
  || fail 'Papirus icon theme package metadata is missing from the ISO rootfs'
for package in kparts kio kiconthemes breeze-icons; do
  grep -Eq "/var/lib/pacman/local/${package}-[^/]*/" <<<"$manifest" \
    || fail "Calamares dependency chain package is missing from ISO rootfs: $package"
done
source "$script_dir/../distro/packages/calamares/source.env"
calamares_pkgrel=$(awk -F= '$1 == "pkgrel" { print $2; exit }' \
  "$script_dir/../distro/packages/calamares/PKGBUILD")
[[ "$calamares_pkgrel" =~ ^[1-9][0-9]*$ ]] || fail 'DINX Calamares pkgrel is invalid'
calamares_package_version="$CALAMARES_VERSION-$calamares_pkgrel"
calamares_db_dir="var/lib/pacman/local/calamares-$calamares_package_version"
iso_manifest_contains_path "$calamares_db_dir/desc" <<<"$manifest" \
  || fail "DINX Calamares package is missing from the ISO rootfs: $calamares_package_version"
calamares_db_version=$(unsquashfs -no-xattrs -no-progress -cat \
  "$tmp_dir/rootfs.img" "$calamares_db_dir/desc" \
  | awk 'previous == "%VERSION%" { print; exit } { previous = $0 }')
[[ "$calamares_db_version" == "$calamares_package_version" ]] \
  || fail "DINX Calamares package version mismatch: $calamares_db_version"
calamares_depends=$(
  unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "$calamares_db_dir/desc" \
    | awk '$0 == "%DEPENDS%" { in_depends = 1; next } /^%/ { in_depends = 0 } in_depends'
)
if grep -Eq '^plasma-integration([<=>].*)?$' <<<"$calamares_depends"; then
  fail 'DINX Calamares package still declares the unused plasma-integration dependency'
fi
cli_issue=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/issue)
grep -Fq 'DINX Linux' <<<"$cli_issue" || fail 'CLI login banner is not branded as DINX Linux'
if grep -Eiq 'Artix' <<<"$cli_issue"; then
  fail 'CLI login banner still identifies Artix'
fi
for image_manifest in "$manifest" "$livefs_manifest"; do
  # Calamares -> KParts -> KIO -> KIconThemes requires breeze-icons; Papirus remains the selected theme.
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/(breeze-[0-9]|breeze-cursors-|plasma-integration-|plasma-workspace-|qogir-icon-theme-|qqc2-breeze-style-|xdg-desktop-portal-kde-|zathura-|zathura-pdf-mupdf-|libmupdf-)[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'retired Qogir/Breeze style/cursor, Plasma, Zathura or MuPDF packages remain in the ISO'
  fi
  if forbidden_matches=$(grep -E "/var/lib/pacman/local/(ex-vi-compat|vim|vim-runtime)-[^/]*" <<<"$image_manifest"); then
    printf "%s\n" "$forbidden_matches" >&2
    fail "build-only Vim qualification packages remain in the ISO"
  fi
  for build_only_path in \
    usr/bin/ex \
    usr/bin/vedit \
    usr/bin/vi \
    usr/bin/view \
    usr/bin/vim; do
    if iso_manifest_contains_path "$build_only_path" <<<"$image_manifest"; then
      fail "build-only qualification or retired Vim executable remains in the ISO: $build_only_path"
    fi
  done
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/(vlc|vlc-[^/]+|libvlc)-[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'retired VLC package metadata remains in the ISO'
  fi
  for retired_media_path in \
    usr/bin/vlc \
    usr/bin/qvlc \
    usr/share/applications/vlc.desktop \
    usr/local/share/applications/vlc.desktop; do
    if grep -Fq "/$retired_media_path" <<<"$image_manifest"; then
      fail "retired VLC payload remains in the ISO: $retired_media_path"
    fi
  done
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/transit-[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'disabled Transit package metadata remains in the ISO'
  fi
  for retired_transit_path in \
    usr/bin/transit \
    opt/transit \
    usr/share/applications/transit.desktop; do
    if grep -Fq "/$retired_transit_path" <<<"$image_manifest"; then
      fail "disabled Transit payload remains in the ISO: $retired_transit_path"
    fi
  done
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/(qps|dome)-[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'disabled Qps or Dome package metadata remains in the ISO'
  fi
  for retired_desktop_path in \
    usr/bin/qps \
    usr/bin/dome \
    usr/share/applications/qps.desktop \
    usr/local/share/applications/qps.desktop \
    usr/share/applications/org.aqueous.Dome.desktop; do
    if grep -Fq "/$retired_desktop_path" <<<"$image_manifest"; then
      fail "disabled Qps or Dome payload remains in the ISO: $retired_desktop_path"
    fi
  done
  for retired_pdf_path in \
    usr/bin/zathura \
    usr/lib/zathura/libpdf-mupdf.so \
    usr/share/applications/org.pwmt.zathura.desktop \
    usr/share/applications/org.pwmt.zathura-pdf-mupdf.desktop \
    usr/local/share/applications/org.pwmt.zathura.desktop; do
    if grep -Fq "/$retired_pdf_path" <<<"$image_manifest"; then
      fail "retired Zathura/MuPDF payload remains in the ISO: $retired_pdf_path"
    fi
  done
done
for image_manifest in "$manifest" "$livefs_manifest"; do
  for strawberry_path in usr/bin/strawberry usr/share/applications/org.strawberrymusicplayer.strawberry.desktop; do
    if grep -Fq "/$strawberry_path" <<<"$image_manifest"; then
      fail "retired Strawberry payload remains in the ISO: $strawberry_path"
    fi
  done
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/strawberry-[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'retired Strawberry package metadata remains in the ISO'
  fi
  for kolourpaint_path in \
    usr/bin/kolourpaint \
    usr/share/applications/org.kde.kolourpaint.desktop \
    usr/local/share/applications/org.kde.kolourpaint.desktop; do
    if grep -Fq "/$kolourpaint_path" <<<"$image_manifest"; then
      fail "retired KolourPaint payload remains in the ISO: $kolourpaint_path"
    fi
  done
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/kolourpaint-[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'retired KolourPaint package metadata remains in the ISO'
  fi
  for bc250_path in \
    usr/bin/cyan-skillfish-governor-smu \
    usr/bin/bc250-control-center \
    usr/bin/bc250-control-center-cli \
    usr/bin/bc250-control-centerd \
    etc/cyan-skillfish-governor-smu/config.toml \
    etc/dinit.d/cyan-skillfish-governor-smu \
    etc/dinit.d/boot.d/cyan-skillfish-governor-smu \
    usr/local/libexec/dinx-cyan-skillfish-governor \
    usr/libexec/bc250-control-center/bc250-package-maintenance \
    usr/share/bc250-control-center/VERSION \
    usr/share/applications/io.github.movacx.bc250-control-center.desktop \
    usr/share/metainfo/io.github.movacx.bc250-control-center.metainfo.xml \
    usr/share/polkit-1/actions/io.github.movacx.bc250-control-center.policy \
    usr/share/icons/hicolor/256x256/apps/bc250-control-center.png \
    usr/share/pixmaps/bc250-control-center.png \
    usr/share/licenses/bc250-control-center/LICENSE; do
    if grep -Fq "/$bc250_path" <<<"$image_manifest"; then
      fail "BC-250-specific payload is present in the generic ISO: $bc250_path"
    fi
  done
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/(bc250-control-center|cyan-skillfish-governor-smu(-dinit)?)-[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'BC-250 package metadata is present in the generic ISO'
  fi
  for gaming_path in \
    usr/bin/gamescope \
    usr/bin/gamemoderun \
    usr/bin/mangohud \
    usr/bin/steam \
    usr/share/applications/steam.desktop; do
    if grep -Fq "/$gaming_path" <<<"$image_manifest"; then
      fail "optional gaming payload is present in the generic ISO: $gaming_path"
    fi
  done
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/(gamescope|gamemode|mangohud|steam(-devices)?|lib32-(gamemode|mesa|vulkan-radeon|vulkan-mesa-layers))-[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'optional gaming package metadata is present in the generic ISO'
  fi
  terminal_binary_matches=$(grep -E '/squashfs-root/(usr/bin|usr/local/bin)/(foot|ghostty|kitty|alacritty|konsole|xterm|xfce4-terminal|gnome-terminal|wezterm|tilix)([[:space:]]|$)' <<<"$image_manifest" || true)
  if [[ -n "$terminal_binary_matches" ]]; then
    printf '%s\n' "$terminal_binary_matches" >&2
    fail 'an alternative terminal emulator executable is present in the ISO'
  fi
  terminal_desktop_matches=$(grep -E '/squashfs-root/usr/share/applications/[^[:space:]]*(foot|ghostty|kitty|alacritty|konsole|xterm|xfce4-terminal|gnome-terminal|wezterm|tilix)[^[:space:]]*\.desktop([[:space:]]|$)' <<<"$image_manifest" || true)
  if [[ -n "$terminal_desktop_matches" ]]; then
    printf '%s\n' "$terminal_desktop_matches" >&2
    fail 'an alternative terminal emulator desktop launcher is present in the ISO'
  fi
  terminal_package_matches=$(grep -E '/var/lib/pacman/local/(foot|ghostty|kitty|alacritty|konsole|xterm|xfce4-terminal|gnome-terminal|wezterm|tilix)-[0-9][^/]*/' <<<"$image_manifest" || true)
  if [[ -n "$terminal_package_matches" ]]; then
    printf '%s\n' "$terminal_package_matches" >&2
    fail 'an alternative terminal emulator package is installed in the ISO'
  fi
done
for image_manifest in "$manifest" "$livefs_manifest"; do
  if grep -Eq '/var/lib/pacman/local/(linux-headers|pahole)-[^/]*/' <<<"$image_manifest"; then
    fail 'build-only linux-headers or pahole package metadata is present in a final ISO filesystem'
  fi
  if forbidden_matches=$(grep -E '/var/lib/pacman/local/(clang-[0-9]|clang-libs-[0-9]|llvm-[0-9]|openshadinglanguage-[0-9])[^/]*/' <<<"$image_manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail 'builder-only compiler or disabled Cycles OSL package metadata is present in a final ISO filesystem'
  fi
  for compiler_path in usr/bin/clang usr/bin/clang++ usr/bin/clangd usr/bin/llvm-config usr/bin/oslc; do
    if iso_manifest_contains_path "$compiler_path" <<<"$image_manifest"; then
      fail "builder-only compiler or disabled Cycles OSL executable is present in the ISO: $compiler_path"
    fi
  done
done
terminal_desktops=$(grep -oE 'squashfs-root/usr/share/applications/[^[:space:]]+\.desktop' <<<"$manifest" | sort -u || true)
while IFS= read -r desktop_path; do
  [[ -n "$desktop_path" ]] || continue
  desktop_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "${desktop_path#squashfs-root/}")
  if grep -Eq '^Categories=.*TerminalEmulator(;|$)' <<<"$desktop_config" \
    && ! grep -Eq '^(Exec|TryExec)=(deetty|/usr/bin/deetty)([[:space:]]|$)' <<<"$desktop_config"; then
    fail "terminal-emulator desktop entry does not launch Deetty: ${desktop_path#squashfs-root/}"
  fi
done <<<"$terminal_desktops"
for deetty_path in \
  usr/bin/deetty \
  usr/bin/dintor \
  usr/share/applications/org.dinx.Deetty.desktop \
  usr/share/applications/org.dinx.Dintor.desktop \
  usr/share/icons/hicolor/scalable/apps/org.dinx.Deetty.svg \
  usr/share/icons/hicolor/scalable/apps/org.dinx.Dintor.svg \
  usr/share/licenses/deetty/LICENSE; do
  grep -Fq "/$deetty_path" <<<"$manifest" \
    || fail "Deetty/Dintor runtime payload is missing: $deetty_path"
done
deetty_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/org.dinx.Deetty.desktop)
grep -Fqx 'Name=Deetty' <<<"$deetty_desktop" || fail 'Deetty desktop entry has the wrong product name'
grep -Fqx 'TryExec=deetty' <<<"$deetty_desktop" || fail 'Deetty desktop entry does not launch Deetty'
grep -Fqx 'Exec=deetty --open-uri %u' <<<"$deetty_desktop" || fail 'Deetty URI handler does not launch Deetty'
dintor_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/org.dinx.Dintor.desktop)
grep -Fqx 'Name=Editor' <<<"$dintor_desktop" || fail 'Dintor desktop entry has the wrong launcher name'
grep -Fqx 'Exec=dintor %F' <<<"$dintor_desktop" || fail 'Dintor desktop entry does not launch Dintor'
grep -Fq '/var/lib/pacman/local/deetty-' <<<"$manifest" || fail 'Deetty package metadata is missing from the installed rootfs'
grep -Fq '/var/lib/pacman/local/squashfs-tools-' <<<"$manifest" \
  || fail 'SquashFS runtime package metadata is missing from the ISO rootfs'
grep -Fq '/var/lib/pacman/local/ghostty-vt-runtime-' <<<"$manifest" || fail 'Ghostty VT-only runtime package metadata is missing from the installed rootfs'
if grep -Eq '/var/lib/pacman/local/ghostty-[0-9][^/]*/' <<<"$manifest"; then
  fail 'full Ghostty terminal package metadata is present in the installed rootfs'
fi
dinit_tmpfiles=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/tmpfiles.d/dinx-dinit.conf)
grep -Fqx 'd /var/log/dinit 0755 root root -' <<<"$dinit_tmpfiles" \
  || fail 'ISO does not recreate the Dinit service log directory at boot'
doctor=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/bin/dinx-doctor)
grep -Fq 'schema dinx-doctor/v1' <<<"$doctor" || fail 'DINX doctor schema is missing'
grep -Fq 'mode read-only' <<<"$doctor" || fail 'DINX doctor is not read-only'
if grep -Eq '(^|[[:space:]])(systemctl|sudo|pkexec|curl|wget)([[:space:]]|$)|pacman[[:space:]]+-S([[:space:]]|$)|dinitctl[[:space:]]+(start|stop|restart)([[:space:]]|$)' <<<"$doctor"; then
  fail 'DINX doctor contains a mutating, privileged or network command'
fi
gaming_launcher=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-gaming)
grep -Fq 'dinitui --gaming-enter' <<<"$gaming_launcher" || fail 'DINX gaming launcher does not enter the Gaming profile'
grep -Fq 'gamescope --backend drm --steam --fullscreen -- steam -tenfoot' <<<"$gaming_launcher" || fail 'DINX gaming launcher command is incorrect'
grep -Fq 'dinitui --gaming-leave' <<<"$gaming_launcher" || fail 'DINX gaming launcher does not restore the previous profile'
if grep -Eq 'systemctl|/bin/sh -c|dbus-daemon' <<<"$gaming_launcher"; then
  fail 'DINX gaming launcher contains a forbidden init or shell indirection'
fi
gaming_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/wayland-sessions/dinx-gaming.desktop)
grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-gaming' <<<"$gaming_session" || fail 'DINX gaming session command is incorrect'
grep -Fq 'Hidden=true' <<<"$gaming_session" || fail 'DINX gaming session is not hidden'
grep -Fq 'NoDisplay=true' <<<"$gaming_session" || fail 'DINX gaming session remains selectable'
river_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/wayland-sessions/dinx-river-kwm-morghulis.desktop)
grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-river-session' <<<"$river_session" \
  || fail 'DINX River session command is incorrect'
grep -Fq 'DesktopNames=Morghulis' <<<"$river_session" || fail 'DINX session desktop identity is not Morghulis'
redbean_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/wayland-sessions/dinx-river-kwm-redbean.desktop)
grep -Fq 'Exec=/usr/local/libexec/dinx-redbean-session' <<<"$redbean_session" \
  || fail 'Redbean session does not select the Redbean wrapper'
grep -Fq 'Name=River + KWM + Redbean (DINX)' <<<"$redbean_session" \
  || fail 'Redbean session identity is incorrect'
redbean_wrapper=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-redbean-session)
grep -Fq 'export DINX_SHELL=redbean' <<<"$redbean_wrapper" \
  || fail 'Redbean wrapper does not select the Redbean shell'
river_launcher=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-river-session)
river_init=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-river-init)
grep -Fq 'exec river -c /usr/local/libexec/dinx-river-init' <<<"$river_launcher" || fail 'DINX River wrapper does not start River'
grep -Fq 'dinx_apply_graphics_environment "$graphics_profile"' <<<"$river_launcher" \
  || fail 'DINX River wrapper does not apply the selected renderer policy'
grep -Fq 'start kwm' <<<"$river_init" || fail 'DINX River init does not start KWM'
grep -Fq 'start morghulis' <<<"$river_init" || fail 'DINX River init does not start Morghulis'
grep -Fq 'start redbean' <<<"$river_init" || fail 'DINX River init does not start Redbean'
grep -Fq 'shell=${DINX_SHELL:-morghulis}' <<<"$river_init" || fail 'DINX River init has no shell selector'
grep -Fq 'start pcmanfm --desktop' <<<"$river_init" || fail 'DINX River init does not start PCManFM desktop mode'
grep -Fq 'start shikane' <<<"$river_init" || fail 'DINX River init does not start Shikane'
grep -Fq 'start /usr/local/libexec/dinx-idle' <<<"$river_init" || fail 'DINX River init does not start the idle manager'
graphics_environment=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-graphics-environment.sh)
grep -Fq 'export WLR_RENDERER=gles2' <<<"$graphics_environment" || fail 'DINX QEMU renderer policy is not set to GLES2'
grep -Fq 'export WLR_RENDERER=vulkan' <<<"$graphics_environment" || fail 'DINX VirtualBox/default renderer policy is not set to Vulkan'
grep -Fq 'export WLR_RENDERER=pixman' <<<"$graphics_environment" || fail 'DINX CPU compatibility renderer policy is missing'
grep -Fq 'unset GSK_RENDERER' <<<"$graphics_environment" || fail 'DINX virtual graphics profiles do not leave GTK4 renderer selection automatic'
for graphics_module in virtio-gpu vmwgfx; do
  grep -Eq "/usr/lib/modules/[^[:space:]]*/kernel/drivers/gpu/drm/.*/${graphics_module}\\.ko(\\.(zst|xz|gz))?([[:space:]]|$)" <<<"$manifest" \
    || fail "ISO kernel DRM module is missing for VM compatibility: $graphics_module"
done
theme_sync=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-sync-session-theme)
grep -Fq 'morghulis/preferences.json' <<<"$theme_sync" || fail 'Morghulis theme preferences are not synchronized'
grep -Fq 'gtk-application-prefer-dark-theme' <<<"$theme_sync" || fail 'GTK dark/light selection is not synchronized'
grep -Fq 'custom_palette' <<<"$theme_sync" || fail 'Qt6ct dark/light palette selection is not synchronized'
first_run=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-morghulis-first-run)
grep -Fq 'morghulis-first-run-complete' <<<"$first_run" || fail 'Morghulis first-run marker is missing'
grep -Fq 'DINX_THEME_VARIANT=$variant' <<<"$first_run" || fail 'Morghulis first-run does not apply its theme choice'
if grep -Eiq 'systemd|systemctl|uwsm|loginctl' <<<"$river_session$river_launcher$river_init$theme_sync$first_run"; then
  fail 'DINX River/Morghulis session contains a forbidden systemd or uwsm integration'
fi


session_entries=$(grep -oE '/usr/share/(wayland-sessions|xsessions)/[^[:space:]]+\.desktop' <<<"$manifest" | sort -u || true)
while IFS= read -r session_path; do
  [[ -n "$session_path" ]] || continue
  case "$session_path" in
    /usr/share/wayland-sessions/dinx-river-kwm-morghulis.desktop|/usr/share/wayland-sessions/dinx-river-kwm-redbean.desktop) ;;
    /usr/share/wayland-sessions/dinx-gaming.desktop)
      session_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "${session_path#/}")
      grep -Fq 'Hidden=true' <<<"$session_config" \
        || fail "gaming session remains visible: $session_path"
      grep -Fq 'NoDisplay=true' <<<"$session_config" \
        || fail "gaming session remains discoverable: $session_path"
      continue
      ;;
    *) fail "unsupported user session remains: $session_path" ;;
  esac
  session_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "${session_path#/}")
  grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-river-session' <<<"$session_config" \
    || fail "River session command is incorrect: $session_path"
done <<<"$session_entries"
if grep -Eq '^(Hidden|NoDisplay)=true$' <<<"$river_kwm_session"; then
  fail 'the DINX River/KWM session is hidden from the greeter session list'
fi


grub_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/grub/themes/artix/theme.txt)
grep -Fq 'DINX GRUB theme override.' <<<"$grub_theme" || fail 'DINX GRUB theme override is missing'
if grep -Eq '^[[:space:]]*(menu_pixmap_style|selected_item_pixmap_style)[[:space:]]*=' <<<"$grub_theme"; then
  fail 'DINX GRUB theme still enables opaque menu textures'
fi
grep -Fq 'desktop-color: "#0b0d12"' <<<"$grub_theme" || fail 'DINX GRUB background color is missing'
grep -Fq 'selected_item_color = "#8fb8ff"' <<<"$grub_theme" || fail 'DINX GRUB accent color is missing'
grep -Fq 'file = "logo.png"' <<<"$grub_theme" || fail 'GRUB theme does not display its DINX logo'
grub_defaults=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/default/grub.d/10-dinx-branding.cfg)
grep -Fq 'GRUB_DISTRIBUTOR="DINX"' <<<"$grub_defaults" || fail 'GRUB menu distributor is not DINX'
grep -Fq 'GRUB_THEME="/usr/share/grub/themes/artix/theme.txt"' <<<"$grub_defaults" || fail 'GRUB does not activate the DINX theme'
if grep -Eiq 'artix' <<<"$grub_theme"; then
  fail 'DINX GRUB theme retains Artix branding'
fi
live_grub_defaults=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/default/grub)
grep -Fq 'GRUB_DISTRIBUTOR="DINX"' <<<"$live_grub_defaults" \
  || fail 'live ISO GRUB distributor is not DINX'
grep -Fq 'GRUB_THEME="/usr/share/grub/themes/artix/theme.txt"' <<<"$live_grub_defaults" \
  || fail 'live ISO GRUB does not select the DINX theme'
live_grub_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/share/grub/themes/artix/theme.txt)
grep -Fq 'DINX GRUB theme override.' <<<"$live_grub_theme" \
  || fail 'live ISO GRUB theme override is missing'
if grep -Eiq 'artix' <<<"$live_grub_theme"; then
  fail 'live ISO GRUB theme retains Artix branding'
fi

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /boot/grub/themes/artix/theme.txt "$tmp_dir/iso-grub-theme.txt" \
  -extract /boot/grub/themes/artix/logo.png "$tmp_dir/iso-grub-logo.png" \
  -extract /boot/grub/grub.cfg "$tmp_dir/iso-grub.cfg" \
  -extract /boot/grub/kernels.cfg "$tmp_dir/iso-grub-kernels.cfg" \
  -extract /boot/grub/variable.cfg "$tmp_dir/iso-grub-variable.cfg" \
  >/dev/null
[[ -s "$tmp_dir/iso-grub-theme.txt" && -s "$tmp_dir/iso-grub-logo.png" ]] \
  || fail 'built ISO omits its DINX GRUB theme or boot mark'
[[ -s "$tmp_dir/iso-grub.cfg" && -s "$tmp_dir/iso-grub-kernels.cfg" && -s "$tmp_dir/iso-grub-variable.cfg" ]] \
  || fail 'built ISO omits the DINX live/firmware GRUB boot menu'
grep -Fq 'set default=0' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO GRUB does not select the live boot option by default'
grep -Fq 'set timeout=6' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO GRUB timeout is not six seconds'
grep -Fq 'set timeout_style=menu' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO GRUB does not display its timed boot menu'
grep -Fq 'source /boot/grub/kernels.cfg' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO GRUB does not load its live boot choices'
grep -Fq 'set kopts="quiet splash"' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO boot menu does not enable Plymouth and silent boot'
[[ $(grep -Fc 'menuentry ' "$tmp_dir/iso-grub-kernels.cfg") -eq 4 ]] \
  || fail 'DINX ISO GRUB does not contain exactly the default, compatibility, safe-graphics and verbose live boot choices'
grep -Fq 'menuentry "Start DINX Linux"' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX default live boot choice is missing'
grep -Fq 'menuentry "Start DINX Linux (compatibility)"' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX compatibility live boot choice is missing'
grep -Fq 'menuentry "Start DINX Linux (safe graphics)"' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX safe-graphics live boot choice is missing'
grep -Fq 'menuentry "Start DINX Linux (verbose boot)"' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX verbose live boot choice is missing'
grep -Fqx '        linux /boot/vmlinuz-$2' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX default live boot choice does not boot the stock kernel parameters'
grep -Fq 'linux /boot/vmlinuz-$2 noapic irqpoll' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX compatibility live boot choice does not pass the legacy interrupt parameters'
grep -Fq 'linux /boot/vmlinuz-$2 noapic irqpoll nomodeset plymouth.enable=0' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX safe-graphics live boot choice does not disable the GPU modeset and splash'
grep -Fq 'linux /boot/vmlinuz-$2 noapic irqpoll ignore_loglevel loglevel=8 plymouth.enable=0 vt.default_utf8=0' "$tmp_dir/iso-grub-kernels.cfg" \
  || fail 'DINX verbose live boot choice does not expose the full kernel console'
[[ $(grep -Fc 'menuentry ' "$tmp_dir/iso-grub.cfg") -eq 1 ]] \
  || fail 'DINX ISO GRUB does not contain exactly one firmware choice'
grep -Fq 'if [ "$grub_platform" = "efi" ]; then' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO GRUB firmware choice is not limited to UEFI'
grep -Fq 'menuentry "Boot to the Firmware/BIOS"' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO GRUB firmware choice is missing'
grep -Fq 'fwsetup' "$tmp_dir/iso-grub.cfg" \
  || fail 'DINX ISO GRUB firmware choice does not invoke fwsetup'
grep -Fq 'DINX GRUB theme override.' "$tmp_dir/iso-grub-theme.txt" \
  || fail 'built ISO GRUB theme is not DINX-branded'
if grep -Eiq 'artix' "$tmp_dir/iso-grub-theme.txt"; then
  fail 'built ISO GRUB theme retains Artix branding'
fi
unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/share/grub/themes/artix/theme.txt \
  > "$tmp_dir/livefs-grub-theme.txt"
cmp -s "$tmp_dir/livefs-grub-theme.txt" "$tmp_dir/iso-grub-theme.txt" \
  || fail 'ISO boot GRUB theme differs from the DINX livefs theme'


unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/grub/themes/artix/logo.png \
  > "$tmp_dir/rootfs-grub-logo.png"
unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/share/grub/themes/artix/logo.png \
  > "$tmp_dir/livefs-grub-logo.png"
cmp -s "$tmp_dir/rootfs-grub-logo.png" "$tmp_dir/livefs-grub-logo.png" \
  || fail 'livefs GRUB logo differs from the installed DINX boot mark'
cmp -s "$tmp_dir/rootfs-grub-logo.png" "$tmp_dir/iso-grub-logo.png" \
  || fail 'ISO boot GRUB logo differs from the DINX boot mark'
plymouthd_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/plymouth/plymouthd.conf)
grep -Fqx 'Theme=dinx' <<<"$plymouthd_config" || fail 'Plymouth does not select the DINX splash theme'
plymouth_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/plymouth/themes/dinx/dinx.plymouth)
grep -Fqx 'ModuleName=script' <<<"$plymouth_theme" || fail 'DINX Plymouth theme does not use the script plugin'
grep -Fqx 'ScriptFile=/usr/share/plymouth/themes/dinx/dinx.script' <<<"$plymouth_theme" \
  || fail 'DINX Plymouth theme script path is incorrect'
plymouth_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/dinit.d/dinx-plymouth-quit)
grep -Fqx 'command = /usr/local/libexec/dinx-plymouth-quit' <<<"$plymouth_service" \
  || fail 'Dinit Plymouth handoff service command is incorrect'
grep -Fqx 'depends-on = greetd' <<<"$plymouth_service" \
  || fail 'Dinit Plymouth handoff does not wait for greetd'
plymouth_quit=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-plymouth-quit)
grep -Fq '/usr/bin/plymouth --ping' <<<"$plymouth_quit" || fail 'Dinit Plymouth handoff does not check the daemon'
grep -Fq 'exec /usr/bin/plymouth quit' <<<"$plymouth_quit" || fail 'Dinit Plymouth handoff does not quit the splash'
unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/plymouth/themes/dinx/logo.png \
  > "$tmp_dir/rootfs-plymouth-logo.png"
cmp -s "$tmp_dir/rootfs-grub-logo.png" "$tmp_dir/rootfs-plymouth-logo.png" \
  || fail 'DINX Plymouth logo differs from the canonical GRUB boot mark'
vconsole_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/vconsole.conf)
grep -Fqx 'FONT=ter-124n' <<<"$vconsole_config" || fail 'rootfs console font is not configured to Terminus 12x24'
grep -Fq 'squashfs-root/usr/share/kbd/consolefonts/ter-124n.psf.gz' <<<"$manifest" \
  || fail 'rootfs omits the configured Terminus console font'
for gpu_firmware_dir in i915 xe; do
  grep -Eq "squashfs-root/usr/lib/firmware/${gpu_firmware_dir}/[^[:space:]]" <<<"$manifest" \
    || fail "rootfs omits Intel GPU firmware files: $gpu_firmware_dir"
done
# Legacy ATI Radeon GPUs need their microcode in the live rootfs: without it
# `radeon` hangs in KMS init right after `[drm] radeon kernel modesetting
# enabled.`, which the HP dm1 (AMD E-350 Zacate / Radeon HD 6310 = SUMO2)
# reports as a black screen. Assert the directory plus the exact SUMO2 files
# that board loads, so the omission cannot silently return.
grep -Eq 'squashfs-root/usr/lib/firmware/radeon/[^[:space:]]' <<<"$manifest" \
  || fail 'rootfs omits ATI Radeon GPU firmware files: radeon'
for radeon_firmware in SUMO2_me.bin.zst SUMO2_pfp.bin.zst; do
  grep -Fq "squashfs-root/usr/lib/firmware/radeon/${radeon_firmware}" <<<"$manifest" \
    || fail "rootfs omits Radeon HD 6310 (Zacate) firmware: ${radeon_firmware}"
done


root_greetd_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/greetd/config.toml)
grep -Fq '[general]' <<<"$root_greetd_config" || fail 'installed greetd general section is missing'
grep -Fq 'source_profile = false' <<<"$root_greetd_config" || fail 'installed greetd sources the greeter profile'
grep -Fq 'vt = 7' <<<"$root_greetd_config" \
  || fail 'installed greetd does not use the dedicated VT, separate from tty1 getty'
grep -Fq 'command = "tuigreet --sessions /usr/share/wayland-sessions --remember --time --cmd /usr/local/libexec/dinx-river-session"' <<<"$root_greetd_config" \
  || fail 'installed greetd does not launch the selectable River/KWM sessions'
grep -Fq 'user = "greeter"' <<<"$root_greetd_config" \
  || fail 'installed greetd does not use the greeter account'
if grep -Fq '[initial_session]' <<<"$root_greetd_config"; then
  fail 'installed greetd unexpectedly enables live autologin'
fi
if grep -Eiq 'systemd|systemctl' <<<"$root_greetd_config"; then
  fail 'installed greetd config contains a systemd integration'
fi

grep -Fq '/usr/share/applications/swayimg.desktop' <<<"$manifest" || fail 'Swayimg desktop entry is not in the ISO payload'
grep -Fq 'org.kde.haruna.desktop' <<<"$manifest" || fail 'Haruna desktop entry is not in the ISO payload'
grep -Fq 'com.github.neithern.g4music.desktop' <<<"$manifest" || fail 'Gapless desktop entry is not in the ISO payload'
grep -Fq 'galculator.desktop' <<<"$manifest" || fail 'Galculator desktop entry is not in the ISO payload'
grep -Fq 'pcmanfm.desktop' <<<"$manifest" || fail 'PCManFM desktop entry is not in the ISO payload'
grep -Fq 'octopi.desktop' <<<"$manifest" || fail 'Octopi desktop entry is not in the ISO payload'
gtk3_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/gtk-3.0/settings.ini)
gtk4_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/gtk-4.0/settings.ini)

theme_json=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/dinx/theme/DINX.json)
grep -Fq '"mSurface": "#0b0d12"' <<<"$theme_json" || fail 'DINX surface palette is missing'
grep -Fq '"mPrimary": "#8fb8ff"' <<<"$theme_json" || fail 'DINX primary palette is missing'
grep -Fq 'gtk-theme-name=Adwaita' <<<"$gtk3_settings" || fail 'GTK3 default theme is not Adwaita'
grep -Fq 'gtk-font-name=Noto Sans 10' <<<"$gtk3_settings" || fail 'GTK3 Noto Sans font contract is missing'
grep -Fq 'gtk-icon-theme-name=Papirus' <<<"$gtk3_settings" || fail 'GTK3 default icon theme is not Papirus'
grep -Fq 'gtk-theme-name=Adwaita' <<<"$gtk4_settings" || fail 'GTK4 default theme is not Adwaita'
grep -Fq 'gtk-font-name=Noto Sans 10' <<<"$gtk4_settings" || fail 'GTK4 Noto Sans font contract is missing'
grep -Fq 'gtk-icon-theme-name=Papirus' <<<"$gtk4_settings" || fail 'GTK4 default icon theme is not Papirus'
gtk3_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-3.0/gtk.css)
grep -Fq 'background-color: #0b0d12' <<<"$gtk3_theme" || fail 'DINX GTK3 surface is missing'
grep -Fq 'background-color: #8fb8ff' <<<"$gtk3_theme" || fail 'DINX GTK3 accent is missing'
grep -Fq 'font-family: Noto Sans;' <<<"$gtk3_theme" || fail 'DINX GTK3 font family is missing'
grep -Fq 'font-size: 10pt;' <<<"$gtk3_theme" || fail 'DINX GTK3 font size is missing'
grep -Fq 'background-color: #11151d' <<<"$gtk3_theme" || fail 'DINX GTK3 control surface is missing'
grep -Fq 'background-color: #263249' <<<"$gtk3_theme" || fail 'DINX GTK3 hover state is missing'
if grep -Eq '#(31415d|151923|2859a8)' <<<"$gtk3_theme"; then
  fail 'DINX GTK3 contains an out-of-contract color'
fi
gtk4_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-4.0/gtk.css)
grep -Fq 'background-color: #0b0d12' <<<"$gtk4_theme" || fail 'DINX GTK4 surface is missing'
grep -Fq 'background-color: #8fb8ff' <<<"$gtk4_theme" || fail 'DINX GTK4 accent is missing'
grep -Fq 'font-family: Noto Sans;' <<<"$gtk4_theme" || fail 'DINX GTK4 font family is missing'
grep -Fq 'font-size: 10pt;' <<<"$gtk4_theme" || fail 'DINX GTK4 font size is missing'
grep -Fq 'background-color: #11151d' <<<"$gtk4_theme" || fail 'DINX GTK4 control surface is missing'
grep -Fq 'background-color: #263249' <<<"$gtk4_theme" || fail 'DINX GTK4 hover state is missing'
if grep -Eq '#(31415d|151923|2859a8)' <<<"$gtk4_theme"; then
  fail 'DINX GTK4 contains an out-of-contract color'
fi
calamares_stylesheet=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/branding/dinx/stylesheet.qss)
grep -Fq 'font-family: Noto Sans;' <<<"$calamares_stylesheet" || fail 'Calamares font family is missing'
grep -Fq 'font-size: 10pt;' <<<"$calamares_stylesheet" || fail 'Calamares font size is missing'
grep -Fq 'border-radius: 0' <<<"$calamares_stylesheet" || fail 'Calamares geometry contract is missing'
if grep -Eq 'border-radius: [1-9]|#(31415d|151923|2859a8)' <<<"$calamares_stylesheet"; then
  fail 'Calamares contains an out-of-contract geometry or color'
fi
qt6ct_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/qt6ct/qt6ct.conf)
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/DINX.conf' <<<"$qt6ct_config" || fail 'Qt6ct DINX color path is missing'
grep -Fq 'icon_theme=Papirus' <<<"$qt6ct_config" || fail 'Qt6ct default icon theme is not Papirus'
grep -Fq 'general="Noto Sans,10' <<<"$qt6ct_config" || fail 'Qt6ct Noto Sans font contract is missing'
qt6ct_palette=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/qt6ct/colors/DINX.conf)
grep -Fq 'active_colors=#ffd7dde8, #ff11151d' <<<"$qt6ct_palette" || fail 'Qt6ct DINX palette has an incorrect QPalette role order'
swayimg_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/swayimg/init.lua)
grep -Fq 'swayimg.gallery.window_color = 0xff0b0d12' <<<"$swayimg_config" || fail 'DINX Swayimg surface is missing'
grep -Fq 'swayimg.text.font = "Noto Sans"' <<<"$swayimg_config" || fail 'Swayimg font contract is missing'
grep -Fq 'swayimg.text.size = 10' <<<"$swayimg_config" || fail 'Swayimg text size does not match Noto Sans 10'
gtk_index=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/index.theme)
grep -Fq 'Name=DINX' <<<"$gtk_index" || fail 'DINX GTK theme index is missing'
grep -Fq 'IconTheme=Papirus' <<<"$gtk_index" || fail 'DINX GTK theme does not select Papirus icons'
gtk3_dark_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-3.0/gtk-dark.css)
grep -Fqx '@import url("gtk.css");' <<<"$gtk3_dark_theme" || fail 'DINX GTK3 dark bridge is missing'
gtk4_dark_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-4.0/gtk-dark.css)
grep -Fqx '@import url("gtk.css");' <<<"$gtk4_dark_theme" || fail 'DINX GTK4 dark bridge is missing'

gtk3_system_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/xdg/gtk-3.0/settings.ini)
grep -Fq 'gtk-theme-name=Adwaita' <<<"$gtk3_system_settings" || fail 'System GTK3 theme default is not Adwaita'
grep -Fq 'gtk-icon-theme-name=Papirus' <<<"$gtk3_system_settings" || fail 'System GTK3 icon default is not Papirus'
grep -Fq 'gtk-application-prefer-dark-theme=1' <<<"$gtk3_system_settings" || fail 'System GTK3 dark preference is missing'
gtk4_system_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/xdg/gtk-4.0/settings.ini)
grep -Fq 'gtk-theme-name=Adwaita' <<<"$gtk4_system_settings" || fail 'System GTK4 theme default is not Adwaita'
grep -Fq 'gtk-application-prefer-dark-theme=1' <<<"$gtk4_system_settings" || fail 'System GTK4 dark preference is missing'
grep -Fq 'gtk-icon-theme-name=Papirus' <<<"$gtk4_system_settings" || fail 'System GTK4 icon default is not Papirus'
for firewall_link_manifest in "$manifest" "$livefs_manifest"; do
  grep -Fq 'squashfs-root/etc/dinit.d/boot.d/firewalld -> /etc/dinit.d/firewalld' <<<"$firewall_link_manifest" \
    || fail 'Firewalld Dinit service is not enabled for both installed rootfs and livefs'
done
for firewall_package in firewalld firewall-config firewalld-dinit dinx-firewalld-dinit; do
  grep -Eq "/var/lib/pacman/local/${firewall_package}-[^/]*/" <<<"$manifest" \
    || fail "Firewalld package is missing from installed rootfs: $firewall_package"
done
for required_package in firefox; do
  grep -Eq "/var/lib/pacman/local/${required_package}-[^/]*/" <<<"$manifest" \
    || fail "required package metadata is missing from installed rootfs: $required_package"
done
for image_manifest in "$manifest" "$livefs_manifest"; do
  for retired_path in \
    usr/bin/portmaster \
    usr/lib/portmaster/portmaster \
    usr/lib/portmaster/portmaster-core \
    usr/lib/portmaster/portmaster.zip \
    usr/lib/portmaster/assets.zip \
    usr/local/libexec/dinx-portmaster-core-service \
    etc/dinit.d/portmaster \
    etc/dinit.d/boot.d/portmaster \
    usr/share/applications/portmaster.desktop \
    usr/share/licenses/portmaster/LICENSE \
    usr/lib/libayatana-appindicator3.so.1 \
    usr/bin/ufw \
    usr/bin/gufw \
    usr/bin/gufw-pkexec \
    etc/ufw/ufw.conf \
    etc/dinit.d/ufw \
    usr/share/applications/gufw.desktop \
    usr/local/share/applications/gufw.desktop \
    usr/local/libexec/dinx-gufw \
    usr/bin/opensnitchd \
    usr/bin/opensnitch-ui \
    etc/opensnitchd/default-config.json \
    usr/share/applications/opensnitch_ui.desktop \
    etc/dinit.d/opensnitchd \
    etc/dinit.d/boot.d/opensnitchd \
    etc/xdg/autostart/opensnitch-ui.desktop \
    usr/share/icons/hicolor/scalable/apps/opensnitch-ui.svg; do
    if grep -Fq "$retired_path" <<<"$image_manifest"; then
      fail "retired firewall payload remains in the ISO: $retired_path"
    fi
  done
  # Artix iproute2 requires libxtables; iptables may provide it transitively.
  for retired_package in portmaster libayatana-appindicator; do
    if iso_manifest_contains_package "$retired_package" <<<"$image_manifest"; then
      fail "retired package remains in a final ISO filesystem: $retired_package"
    fi
  done
  for retired_package_metadata in floorp onlyoffice impasto zrythm topgrade; do
    if grep -Eq "/var/lib/pacman/local/${retired_package_metadata}-[^/]*/" <<<"$image_manifest"; then
      fail "retired desktop package metadata remains in a final ISO filesystem: $retired_package_metadata"
    fi
  done
done

idle_wrapper=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-idle)
grep -Fq 'wlopm --off "*"' <<<"$idle_wrapper" || fail 'DINX live idle manager does not blank displays'
grep -Fq 'wlopm --on "*"' <<<"$idle_wrapper" || fail 'DINX live idle manager does not wake displays'
lock_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinx-lock.desktop)
grep -Fq 'Exec=/usr/local/libexec/dinx-lock' <<<"$lock_desktop" || fail 'DINX lock launcher is missing'
shell_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/profile.d/dinx.sh)
grep -Fq 'export TERMINAL="${TERMINAL:-deetty}"' <<<"$shell_config" || fail 'DINX shell does not default to Deetty'
grep -Fq 'export TERMINAL="${TERMINAL:-deetty}"' <<<"$river_launcher" || fail 'River session does not default to Deetty'
grep -Fq 'EDITOR=' <<<"$shell_config" || fail 'DINX shell editor default is missing'
grep -Fq 'QT_QPA_PLATFORMTHEME=' <<<"$shell_config" || fail 'Qt6ct session integration is missing'
grep -Fq 'DINX_COLOR_SCHEME=' <<<"$shell_config" || fail 'DINX color scheme session integration is missing'
grep -Fq 'export SHELL=/bin/fish' <<<"$shell_config" || fail 'DINX POSIX shell default is not Fish'
fish_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/fish/config.fish)
grep -Fq 'set -gx SHELL /bin/fish' <<<"$fish_config" || fail 'DINX Fish shell default is missing'
grep -Fq 'set -gx TERMINAL deetty' <<<"$fish_config" || fail 'DINX Fish does not default to Deetty'
useradd_defaults=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/default/useradd)
grep -Fq 'SHELL=/bin/fish' <<<"$useradd_defaults" || fail 'new-user shell default is not Fish'
users_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/users.conf)
grep -Fq 'shell: /bin/fish' <<<"$users_config" || fail 'Calamares user shell is not Fish'
grep -Fq '    - render' <<<"$users_config" || fail 'Calamares users are missing DRM render-node access'
mimeapps_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/xdg/mimeapps.list)
grep -Fq 'inode/directory=pcmanfm.desktop;' <<<"$mimeapps_config" || fail 'PCManFM is not the default directory handler'
grep -Fq 'text/html=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTML handler'
grep -Fq 'application/xhtml+xml=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default XHTML handler'
grep -Fq 'x-scheme-handler/http=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTTP handler'
grep -Fq 'x-scheme-handler/https=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTTPS handler'
firefox_policy=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/lib/firefox/distribution/policies.json)
grep -Fq '"DisableAppUpdate": true' <<<"$firefox_policy" || fail 'Firefox updates are not managed by the DINX policy'
grep -Fq 'application/pdf=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default PDF handler'
if grep -Fq 'application/epub+zip=' <<<"$mimeapps_config"; then
  fail 'orphan EPUB handler remains after Zathura removal'
fi
grep -Fq 'image/png=swayimg.desktop;' <<<"$mimeapps_config" || fail 'Swayimg is not the default PNG handler'
for video_mime in video/mp4 video/mpeg video/webm video/x-matroska; do
  grep -Fq "$video_mime=org.kde.haruna.desktop;" <<<"$mimeapps_config" \
    || fail "Haruna is not the default video handler for $video_mime"
done
for audio_mime in audio/mpeg audio/x-mpeg audio/x-mp3 audio/ogg audio/x-vorbis audio/x-vorbis+ogg audio/x-opus+ogg audio/flac audio/x-flac audio/wav audio/x-wav; do
  grep -Fq "$audio_mime=com.github.neithern.g4music.desktop;" <<<"$mimeapps_config" \
    || fail "Gapless is not the default audio handler for $audio_mime"
done
if grep -Fq 'strawberry' <<<"$mimeapps_config"; then
  fail 'retired Strawberry handlers remain in the ISO'
fi
gapless_schema=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/glib-2.0/schemas/com.github.neithern.g4music.gschema.xml)
grep -A2 -F '<key name="gapless-playback" type="b">' <<<"$gapless_schema" \
  | grep -Fq '<default>true</default>' || fail 'Gapless gapless playback is not enabled by default'
gapless_dbus=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/dbus-1/services/com.github.neithern.g4music.service)
grep -Fq 'Name=com.github.neithern.g4music' <<<"$gapless_dbus" || fail 'Gapless D-Bus activation name is missing'
grep -Fq 'Exec=/usr/bin/g4music --gapplication-service' <<<"$gapless_dbus" || fail 'Gapless D-Bus activation command is missing'
for archive_mime in application/zip application/x-7z-compressed application/vnd.rar application/x-tar application/gzip application/x-bzip2 application/x-xz application/zstd; do
  grep -Fq "$archive_mime=org.gnome.FileRoller.desktop;" <<<"$mimeapps_config" || fail "File Roller is not the default archive handler for $archive_mime"
done

# Artix desktop packages may ship inert compatibility unit files; reject the init/runtime itself.
# Empty compatibility directories are inert; reject files and symlinks under these paths.

# Reject the upstream terminal/editor install paths; Deetty/Dintor own the DINX payload.
for forbidden_path in \
  etc/systemd \
  usr/lib/systemd \
  usr/lib/systemd/systemd \
  usr/lib/systemd/user/bc250-control-centerd.service \
  usr/lib/systemd/system/cyan-skillfish-governor-smu.service.d/91-bc250-control-center-overlay-preflight.conf \
  etc/uwsm \
  usr/share/uwsm \
  usr/bin/uwsm \
  usr/bin/systemd \
  usr/bin/systemctl \
  usr/bin/regreet \
  usr/bin/labwc \
  usr/bin/noctalia \
  usr/local/libexec/dinx-labwc \
  etc/xdg/labwc \
  etc/xdg/labwc-greeter \
  usr/bin/noctty \
  usr/bin/nocted \
  usr/share/applications/com.noctty.NOCTTY.desktop \
  usr/share/applications/com.noctty.NoctEd.desktop \
  usr/share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg \
  usr/share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg \
  usr/share/kio/servicemenus/nocttyhere.desktop \
  usr/share/nocted \
  usr/share/licenses/noctty \
  usr/share/deetty/noctalia \
  usr/share/noctty/noctalia \
  usr/bin/xfce4-session \
  usr/bin/xfdesktop \
  usr/bin/xfwm4 \
  usr/bin/xfce4-panel \
  usr/bin/lxqt-session \
  usr/bin/lxqt-panel \
  usr/bin/lxqt-runner \
  usr/bin/thunar \
  usr/bin/partitionmanager \
  usr/share/applications/thunar.desktop \
  usr/share/applications/org.kde.partitionmanager.desktop \
  usr/lib/gvfs \
  usr/lib/tumbler; do
  if forbidden_matches=$(grep -F "/$forbidden_path" <<<"$manifest" | grep -v '^d'); then
    printf '%s\n' "$forbidden_matches" >&2
    fail "forbidden desktop/runtime payload is present: $forbidden_path"
  fi
done
if forbidden_matches=$(grep -E '/var/lib/pacman/local/(gvfs|gvfs-gphoto2|gvfs-mtp|gvfs-smb|partitionmanager|thunar|thunar-archive-plugin|thunar-volman|tumbler)-[^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'removed file-manager, volume-mounter or partition-manager package metadata is present'
fi
for image_manifest in "$manifest" "$livefs_manifest"; do
  for removed_package in \
    dhcpcd dhcpcd-dinit dhclient ecryptfs-utils ex-vi-compat exfat-utils \
    man-db man-pages memtest86+ mkinitcpio-nfs-utils nbd s-nail texinfo \
    vi vim vim-runtime zsh; do
    if grep -Fq "/var/lib/pacman/local/$removed_package-" <<<"$image_manifest"; then
      fail "trimmed common package metadata remains in the ISO: $removed_package"
    fi
  done
  for removed_path in usr/bin/info usr/bin/man; do
    if iso_manifest_contains_path "$removed_path" <<<"$image_manifest"; then
      fail "trimmed documentation executable remains in the ISO: $removed_path"
    fi
  done
done
for exfat_path in usr/bin/fsck.exfat usr/bin/mkfs.exfat; do
  grep -Fq "/$exfat_path" <<<"$manifest" || fail "kernel exFAT utility is missing from the ISO: $exfat_path"
done

if forbidden_matches=$(grep -E '/var/lib/pacman/local/(labwc|noctalia)-[^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'retired Labwc/Noctalia package metadata is present'
fi
if forbidden_matches=$(grep -E '/var/lib/pacman/local/(aqueous|aqueous-cpu|pearl|dinx-pearl-themes|matugen)-[0-9][^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'retired Aqueous/Pearl compositor package metadata is present'
fi
for image_manifest in "$manifest" "$livefs_manifest"; do
  for retired_compositor_path in \
    usr/bin/aqueous \
    usr/bin/aqueous-cpu \
    usr/bin/aqueousctl \
    usr/bin/aqueous-config \
    usr/bin/pearl \
    usr/bin/pearl-greeter \
    usr/lib/pearl \
    usr/share/pearl-greeter \
    usr/share/pearl/themes \
    etc/pearl \
    etc/xdg/aqueous \
    etc/skel/.config/pearl \
    usr/local/libexec/dinx-pearl-shell \
    usr/local/libexec/dinx-pearl-greeter-host \
    usr/local/libexec/dinx-aqueous-pearl \
    usr/local/libexec/dinx-aqueous-init \
    usr/local/libexec/dinx-seed-aqueous-live-config \
    usr/local/libexec/dinx-tune-aqueous-config \
    usr/share/polkit-1/actions/org.aqueous.Pearl.Greeter.Appearance.policy \
    usr/share/wayland-sessions/dinx-aqueous-pearl.desktop \
    usr/lib/aqueous \
    usr/share/aqueous \
    usr/share/aqueous-protocols \
    usr/share/pkgconfig/aqueous-protocols.pc \
    usr/share/doc/aqueous \
    usr/share/licenses/aqueous \
    usr/share/licenses/pearl \
    usr/share/licenses/matugen \
    usr/bin/matugen \
    usr/local/libexec/dinx-first-run-wizard; do
    if forbidden_matches=$(grep -F "/$retired_compositor_path" <<<"$image_manifest" | grep -v '^d'); then
      printf '%s\n' "$forbidden_matches" >&2
      fail "retired Aqueous/Pearl payload remains in the ISO: $retired_compositor_path"
    fi
  done
done
if forbidden_matches=$(grep -E '/var/lib/pacman/local/greetd-regreet-[^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'retired ReGreet package metadata is present'
fi
if forbidden_matches=$(grep -E '/var/lib/pacman/local/systemd-[0-9][^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'systemd init package metadata is present; compatibility libraries are allowed'
fi
if forbidden_matches=$(grep -E '/var/lib/pacman/local/(xorg-server-[0-9]|xorg-xinit-[0-9]|xorg-xhost-[0-9]|xf86-(input|video)-|xlibre-)[^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'legacy X11 server, driver or session packages are present in the ISO payload'
fi
if forbidden_matches=$(grep -E '/var/lib/pacman/local/uwsm-[^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'uwsm package metadata is present; the DINX River path is direct'
fi
for forbidden_path in \
  etc/systemd \
  usr/lib/systemd \
  usr/bin/systemd \
  usr/bin/systemctl \
  usr/bin/regreet \
  etc/uwsm \
  usr/share/uwsm \
  usr/bin/uwsm; do
  if forbidden_matches=$(grep -F "/$forbidden_path" <<<"$livefs_manifest" | grep -v '^d'); then
    printf '%s\n' "$forbidden_matches" >&2
    fail "forbidden livefs init payload is present: $forbidden_path"
  fi
done
if forbidden_matches=$(grep -E '/var/lib/pacman/local/(systemd-[0-9]|uwsm-|greetd-regreet-)[^/]*/' <<<"$livefs_manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'forbidden livefs init or greeter package metadata is present'
fi

grep -Fq '/usr/bin/os-prober' <<<"$manifest" || fail 'os-prober is missing from the ISO payload'
grep -Fq '/usr/bin/mount' <<<"$manifest" || fail 'util-linux mount is missing from the ISO payload'
grep -Fq '/usr/bin/flock' <<<"$manifest" || fail 'util-linux flock is missing from the ISO payload'
if grep -Fq '/usr/bin/ntfs-3g' <<<"$manifest"; then
  fail 'optional ntfs-3g write package is present in the live ISO'
fi
grep -Eq '/usr/lib/modules/[^/]+/kernel/fs/ntfs3/ntfs3\.ko' <<<"$manifest" || fail 'kernel ntfs3 read/write support is missing from the ISO payload'
grep -Eq '/usr/lib/modules/[^/]+/kernel/drivers/gpu/drm/virtio/virtio-gpu\.ko(\.(zst|xz|gz))?$' <<<"$manifest" || fail 'QEMU virtio-gpu DRM module is missing from the ISO payload'
grep -Eq '/usr/lib/modules/[^/]+/kernel/drivers/gpu/drm/vmwgfx/vmwgfx\.ko(\.(zst|xz|gz))?$' <<<"$manifest" || fail 'VirtualBox VMSVGA vmwgfx module is missing from the ISO payload'
grep -Eq '/usr/lib/modules/[^/]+/kernel/drivers/gpu/drm/vboxvideo/vboxvideo\.ko(\.(zst|xz|gz))?$' <<<"$manifest" || fail 'VirtualBox vboxvideo DRM module is missing from the ISO payload'
grep -Eq '/usr/lib/modules/[^/]+/kernel/drivers/gpu/drm/qxl/qxl\.ko(\.(zst|xz|gz))?$' <<<"$manifest" || fail 'QEMU QXL DRM module is missing from the ISO payload'


calamares_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/settings.conf)
grep -Fq 'branding: dinx' <<<"$calamares_settings" || fail 'DINX Calamares branding is not selected'
grep -Fq 'services-artix' <<<"$calamares_settings" || fail 'Calamares dinit service module is not selected'
grep -Fq 'postcfg' <<<"$calamares_settings" || fail 'Calamares dinit user-service module is not selected'
calamares_services=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/services-artix.conf)
calamares_mount=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/mount.conf)
calamares_bootloader=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/bootloader.conf)
grub_windows=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/default/grub.d/40-dinx-windows.cfg)
grep -Fq 'subvolume: ""' <<<"$calamares_mount" || fail 'Calamares Btrfs existing-subvolume guard is missing'
grep -Fq 'extraMounts:' <<<"$calamares_mount" || fail 'Calamares target pseudo-filesystem mounts are missing'
grep -Fq 'mountPoint: /proc' <<<"$calamares_mount" || fail 'Calamares target proc mount is missing'
grep -Fq 'mountPoint: /sys' <<<"$calamares_mount" || fail 'Calamares target sys mount is missing'
grep -Fq 'mountPoint: /dev' <<<"$calamares_mount" || fail 'Calamares target dev mount is missing'
grep -Fq 'mountPoint: /run' <<<"$calamares_mount" || fail 'Calamares target run mount is missing'
grep -Fq 'umask=0077' <<<"$calamares_mount" || fail 'Calamares EFI mount options are missing'
grep -Fq 'efiBootloaderId: "DINX"' <<<"$calamares_bootloader" || fail 'Calamares DINX EFI bootloader ID is missing'
grep -Fq 'installEFIFallback: true' <<<"$calamares_bootloader" || fail 'Calamares EFI fallback is not enabled'
grep -Fq 'GRUB_DISABLE_OS_PROBER=false' <<<"$grub_windows" || fail 'GRUB Windows detection is not enabled'
grep -Fq 'getty@tty2' <<<"$calamares_services" || fail 'Calamares recovery TTY service is not selected'
grep -Fq 'getty@tty3' <<<"$calamares_services" || fail 'Calamares second recovery TTY service is not selected'

calamares_branding=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/branding/dinx/stylesheet.qss)
grep -Fq '#0b0d12' <<<"$calamares_branding" || fail 'DINX Calamares surface is missing'
grep -Fq '#8fb8ff' <<<"$calamares_branding" || fail 'DINX Calamares accent is missing'
calamares_branding_desc=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/branding/dinx/branding.desc)
grep -Fq 'SidebarBackground: "#11151d"' <<<"$calamares_branding_desc" || fail 'DINX Calamares sidebar panel is missing'
grep -Fq 'SidebarText: "#7f8a9c"' <<<"$calamares_branding_desc" || fail 'DINX Calamares sidebar text is missing'
grep -Fq 'SidebarBackgroundCurrent: "#263249"' <<<"$calamares_branding_desc" || fail 'DINX Calamares sidebar selection is missing'
grep -Fq 'productIcon: "dinx-ray-mark.svg"' <<<"$calamares_branding_desc" \
  || fail 'Calamares product icon does not use the DINX D-ray mark'
grep -Fq 'productLogo: "dinx-emblem.png"' <<<"$calamares_branding_desc" \
  || fail 'Calamares product logo does not use the DINX emblem'

installer_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinx-installer.desktop)
grep -Fq 'Name=Install DINX' <<<"$installer_desktop" || fail 'DINX installer English desktop name is missing'
grep -Fq 'Name[pt_BR]=Instalar DINX' <<<"$installer_desktop" || fail 'DINX installer Portuguese desktop name is missing'
grep -Fqx 'TryExec=/usr/local/libexec/dinx-installer' <<<"$installer_desktop" || fail 'DINX installer launcher prerequisite is incorrect'
grep -Fqx 'Exec=/usr/local/libexec/dinx-installer' <<<"$installer_desktop" || fail 'DINX installer launch command is incorrect'
if grep -Eq '^(Hidden|NoDisplay)=true$' <<<"$installer_desktop"; then
  fail 'DINX installer launcher is hidden'
fi
calamares_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/calamares.desktop)
grep -Fqx 'Type=Application' <<<"$calamares_desktop" || fail 'Calamares desktop-ID mask is missing or invalid'
grep -Fqx 'Name=Calamares' <<<"$calamares_desktop" || fail 'Calamares desktop-ID mask is missing its desktop name'
grep -Fqx 'Hidden=true' <<<"$calamares_desktop" || fail 'Calamares Artix launcher is not deleted from the desktop namespace'
grep -Fqx 'NoDisplay=true' <<<"$calamares_desktop" || fail 'Calamares Artix launcher remains visible in application menus'
if grep -Eiq 'Install Artix|Instalar Artix|^(Exec|TryExec)=' <<<"$calamares_desktop"; then
  fail 'Calamares desktop-ID mask retains an Artix identity or executable'
fi
installer_seed=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "etc/skel/Desktop/Install DINX.desktop")
grep -Fq 'Name=Install DINX' <<<"$installer_seed" || fail 'live-user desktop shortcut English name is missing'
grep -Fq 'Name[pt_BR]=Instalar DINX' <<<"$installer_seed" || fail 'live-user desktop shortcut Portuguese name is missing'
grep -Fqx 'Exec=/usr/local/libexec/dinx-installer' <<<"$installer_seed" || fail 'live-user desktop shortcut does not use the DINX launcher'
live_session_launcher=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-river-session)
grep -Fq 'xdg-user-dir DESKTOP' <<<"$live_session_launcher" || fail 'live session does not resolve the user desktop directory'
grep -Fq 'installer_seed="/etc/skel/Desktop/Install DINX.desktop"' <<<"$live_session_launcher" || fail 'live session does not seed its pre-existing user from /etc/skel'
grep -Fq 'mv -n -- "$installer_tmp" "$installer_desktop"' <<<"$live_session_launcher" || fail 'live installer shortcut seeding is not atomic and non-overwriting'
grep -Fq '/usr/local/libexec/dinx-approve-desktop-launcher' <<<"$live_session_launcher" || fail 'live session does not preapprove the trusted installer shortcut for the desktop'
grep -Fq 'DINX_LIVE_SESSION:-' <<<"$live_session_launcher" || fail 'automatic desktop launcher approval is not restricted to the live session'
deetty_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/org.dinx.Deetty.desktop)
grep -Fq 'TryExec=deetty' <<<"$deetty_desktop" || fail 'Deetty desktop launcher is missing'
grep -Fq 'Exec=deetty --open-uri %u' <<<"$deetty_desktop" || fail 'Deetty desktop URI command is incorrect'

dintor_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/org.dinx.Dintor.desktop)
grep -Fq 'Exec=dintor %F' <<<"$dintor_desktop" || fail 'Dintor desktop launcher is missing'
grep -Fq 'Icon=org.dinx.Dintor' <<<"$dintor_desktop" || fail 'Dintor desktop icon is missing'
grep -Fq 'Name=Editor' <<<"$dintor_desktop" || fail 'Dintor English desktop name is missing'
grep -Fq 'Name[pt_BR]=Editor' <<<"$dintor_desktop" || fail 'Dintor Portuguese desktop name is missing'
dinitui_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinitui.desktop)
grep -Fq 'Exec=dinitui' <<<"$dinitui_desktop" || fail 'DinitUI desktop launcher is missing'
grep -Fq 'Name=Services' <<<"$dinitui_desktop" || fail 'DinitUI English desktop name is missing'
grep -Fq 'Name[pt_BR]=Serviços' <<<"$dinitui_desktop" || fail 'DinitUI Portuguese desktop name is missing'
grep -Fq 'Icon=org.dinx.DinitUI' <<<"$dinitui_desktop" || fail 'DinitUI desktop icon contract is missing'
dinxpanel_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinxpanel.desktop)
grep -Fq 'Exec=dinxpanel' <<<"$dinxpanel_desktop" || fail 'DINXPanel desktop launcher is missing'
grep -Fq 'Icon=org.dinx.DinxPanel' <<<"$dinxpanel_desktop" || fail 'DINXPanel desktop icon contract is missing'
grep -Fq 'Name=Control Center' <<<"$dinxpanel_desktop" || fail 'DINXPanel English desktop name is missing'
grep -Fq 'Name[pt_BR]=Central de Controle' <<<"$dinxpanel_desktop" || fail 'DINXPanel Portuguese desktop name is missing'
mission_center_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/io.missioncenter.MissionCenter.desktop)
grep -Fq 'Exec=missioncenter' <<<"$mission_center_desktop" || fail 'Mission Center desktop launcher is missing'
grep -Fq 'Name=Mission Center' <<<"$mission_center_desktop" || fail 'Mission Center desktop name is missing'
grep -Fq 'Icon=io.missioncenter.MissionCenter' <<<"$mission_center_desktop" || fail 'Mission Center desktop icon contract is missing'
file_roller_override=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/share/applications/org.gnome.FileRoller.desktop)
grep -Fq 'Name[pt_BR]=Descompactador' <<<"$file_roller_override" || fail 'File Roller Portuguese desktop name is missing'
grep -Fq 'Name=Archive Manager' <<<"$file_roller_override" || fail 'File Roller English desktop name is missing'
mission_center_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/io.missioncenter.MissionCenter.desktop)
grep -Fq 'Exec=missioncenter' <<<"$mission_center_desktop" || fail 'Mission Center desktop launcher is missing'
grep -Fq 'Name=Mission Center' <<<"$mission_center_desktop" || fail 'Mission Center desktop name is missing'
grep -Fq 'Icon=io.missioncenter.MissionCenter' <<<"$mission_center_desktop" || fail 'Mission Center desktop icon contract is missing'
while IFS='|' read -r path english portuguese command; do
  launcher=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "$path")
  assert_desktop_entry "$path" "$launcher" "$english" "$portuguese" "Exec=$command"
done <<'EOF'
usr/share/applications/firefox.desktop|Firefox|Firefox|firefox %u
usr/local/share/applications/galculator.desktop|Calculator|Calculadora|galculator
usr/local/share/applications/gparted.desktop|Partition Editor|Particionador|/usr/local/libexec/dinx-gparted %f
usr/local/share/applications/swayimg.desktop|Image Viewer|Visualizador de Imagens|swayimg %F
usr/local/share/applications/com.github.neithern.g4music.desktop|Music Player|Tocador de Música|env GTK_THEME=DINX GTK_APPLICATION_PREFER_DARK_THEME=1 g4music %U
usr/local/share/applications/org.kde.haruna.desktop|Media Player|Tocador de Mídia|haruna %U
usr/local/share/applications/blueman-manager.desktop|Bluetooth|Bluetooth|/usr/local/libexec/dinx-bluetooth-manager
usr/local/share/applications/nm-connection-editor.desktop|Network Connections|Ajustes de Rede|nm-connection-editor
usr/local/share/applications/com.saivert.pwvucontrol.desktop|Audio Control|Ajustes de Áudio|pwvucontrol
usr/local/share/applications/org.gnome.FileRoller.desktop|Archive Manager|Descompactador|file-roller %U
usr/share/applications/network.cycles.wdisplays.desktop|Display Settings|Ajustes de Tela|dinx-wdisplays
usr/share/applications/com.pori.app.desktop|Disks & Mounts|Discos e Montagens|/usr/bin/pori
EOF
swayimg_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/share/applications/swayimg.desktop)
grep -Fqx 'NoDisplay=true' <<<"$swayimg_desktop" || fail 'Swayimg is unexpectedly exposed in the app menu'
file_roller_mime_cache=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/share/applications/mimeinfo.cache)
for mime in application/zip application/x-7z-compressed application/vnd.rar application/x-rar application/x-tar application/gzip application/x-gzip application/x-bzip2 application/x-xz application/zstd; do
  grep -Fqx "$mime=org.gnome.FileRoller.desktop;" <<<"$file_roller_mime_cache" || fail "File Roller MIME cache is missing $mime"
done
if grep -E '/var/lib/pacman/local/zls-[^/]*/' <<<"$manifest"; then
  fail 'optional ZLS package metadata is present in the generic ISO'
fi
for retired_zls_path in \
  usr/bin/zls \
  etc/zls.json \
  etc/xdg/zls.json \
  usr/lib/zls/zig-env \
  usr/lib/zls/zig-env.zon \
  usr/lib/zls/zig/std/std.zig; do
  if grep -Fq "/$retired_zls_path" <<<"$manifest"; then
    fail "optional ZLS payload is present in the generic ISO: $retired_zls_path"
  fi
done
if grep -E '/var/lib/pacman/local/eurooffice-[^/]*/' <<<"$manifest"; then
  fail 'optional EuroOffice package metadata is present in the generic ISO'
fi
for retired_eurooffice_path in \
  usr/bin/euro-office-lite \
  usr/bin/eurooffice \
  usr/lib/Euro-Office-Lite/binaries/libkernel.so \
  usr/share/applications/eurooffice.desktop \
  usr/share/licenses/eurooffice/LICENSE; do
  if grep -Fq "/$retired_eurooffice_path" <<<"$manifest"; then
    fail "optional EuroOffice payload is present in the generic ISO: $retired_eurooffice_path"
  fi
done
grep -Fq '/usr/bin/dinitui' <<<"$manifest" || fail 'DinitUI executable is missing'
grep -Fq '/usr/bin/dinxpanel' <<<"$manifest" || fail 'DINXPanel executable is missing'
grep -Fq '/usr/share/icons/hicolor/scalable/apps/org.dinx.DinitUI.svg' <<<"$manifest" || fail 'DinitUI icon is missing'
grep -Fq '/usr/share/icons/hicolor/scalable/apps/org.dinx.DinxPanel.svg' <<<"$manifest" || fail 'DINXPanel icon is missing'
# The two native Zig control apps force the DINX dark palette from compiled-in CSS.
# Assert the shipped binaries carry it, not just their source: a recipe change that
# leaves pkgrel unchanged makes the builder install a stale precompiled artifact whose
# binary predates the theme, which is how DinitUI shipped a light UI while
# check_dinitui.sh still passed on the source.
for native_dark_app in dinitui dinxpanel; do
  native_dark_binary="$tmp_dir/$native_dark_app"
  unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "usr/bin/$native_dark_app" > "$native_dark_binary" \
    || fail "could not extract $native_dark_app for compiled theme inspection"
  grep -aFq 'window.background { background-color: #0b0d12; }' "$native_dark_binary" \
    || fail "$native_dark_app binary does not embed the DINX dark window background; a stale precompiled artifact may have been installed"
done
grep -Fq '/usr/share/dintor/styles/dintor-light.xml' <<<"$manifest" || fail 'Dintor light scheme is missing'


livefs_required_paths=(
  etc/artools/live.conf
  etc/default/grub
  etc/hostname
  etc/dinit.d/boot.d/NetworkManager
  etc/dinit.d/boot.d/artix-live
  etc/dinit.d/boot.d/dinx-live-autologin
  etc/dinit.d/boot.d/dinx-live-session
  etc/dinit.d/dinx-live-session
  etc/dinit.d/boot.d/greetd
  etc/dinit.d/boot.d/logind
  etc/dinit.d/boot.d/metalog
  etc/dinit.d/boot.d/pacman-init
  etc/dinit.d/boot.d/userspawn
  usr/local/libexec/dinx-live-session
  usr/share/grub/themes/artix/theme.txt
  usr/share/grub/themes/artix/logo.png
)

for path in "${livefs_required_paths[@]}"; do
  awk -v wanted="squashfs-root/$path" '
    { for (i = 1; i <= NF; i++) if ($i == wanted || $i == wanted "/") found = 1 }
    END { exit !found }
  ' <<<"$livefs_manifest" || fail "missing livefs path (exact path required): $path"
done
live_hostname=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/hostname)
grep -Fqx 'dinxlive' <<<"$live_hostname" || fail 'livefs hostname is not dinxlive'


live_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/artools/live.conf)
grep -Fq 'AUTOLOGIN=true' <<<"$live_config" || fail 'live session autologin is not enabled'
grep -Fq 'LIVEUSER=dinx' <<<"$live_config" || fail 'live session user is not dinx'

live_autologin_wrapper=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/local/libexec/dinx-live-autologin)
grep -Fq 'install -d -o dinx -g dinx -m 0700 /run/dinx-session' <<<"$live_autologin_wrapper" \
  || fail 'live boot does not provision the private session runtime directory'
grep -Fq "printf '%s\\n' 'dinxlive' > /etc/hostname" <<<"$live_autologin_wrapper" \
  || fail 'live boot does not persist hostname dinxlive'
grep -Fq 'hostname dinxlive' <<<"$live_autologin_wrapper" \
  || fail 'live boot does not set the active hostname to dinxlive'
live_session_launcher=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/local/libexec/dinx-live-session)
grep -Fq 'exec /usr/bin/openvt -c 7 -s -f -e -- runuser -u dinx' <<<"$live_session_launcher" \
  || fail 'live session launcher does not acquire and activate dedicated VT 7'
grep -Fq 'runuser -u dinx' <<<"$live_session_launcher" \
  || fail 'live session launcher does not switch to the dinx user'
grep -Fq 'DINX_LIVE_SESSION=1' <<<"$live_session_launcher" \
  || fail 'live session launcher does not mark the session as live'
grep -Fq 'XDG_RUNTIME_DIR=/run/dinx-session' <<<"$live_session_launcher" \
  || fail 'live session launcher does not use the private runtime directory'
grep -Fq 'dbus-run-session /usr/local/libexec/dinx-river-session' <<<"$live_session_launcher" \
  || fail 'live session launcher does not start River/KWM/Morghulis under a session bus'
live_autologin_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/dinx-live-autologin)
grep -Fq 'before = login.target' <<<"$live_autologin_service" \
  || fail 'live boot preparation does not precede the login target'
grep -Fq 'before = greetd' <<<"$live_autologin_service" \
  || fail 'live boot preparation does not precede the greetd no-op boundary'

live_passwd=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/passwd)
grep -Eq '^dinx:' <<<"$live_passwd" || fail 'live session user dinx is missing'

printf 'ISO content check passed: DINX branding, River/KWM/Morghulis session, Morghulis first-run/theme setup, PCManFM desktop/file-manager defaults, Mission Center, package provenance, optional gaming/BC-250 exclusions, storage/display/desktop/installer payloads, dinit and zstd compression contracts are present.\n'
