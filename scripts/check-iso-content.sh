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

for squashfs in "$tmp_dir/rootfs.img" "$tmp_dir/livefs.img"; do
  squashfs_stats=$(unsquashfs -no-xattrs -no-progress -s "$squashfs")
  grep -Eq 'Compression[[:space:]]+xz([[:space:]]|$)' <<<"$squashfs_stats" \
    || fail "SquashFS image is not xz-compressed: $squashfs"
  grep -Eq 'Block size[[:space:]]+262144([[:space:]]|$)' <<<"$squashfs_stats" \
    || fail "SquashFS image does not use 256 KiB blocks: $squashfs"
done

manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/rootfs.img")
livefs_manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/livefs.img")

for live_path in \
  etc/artools/live.conf \
  etc/dinit.d/dinx-live-autologin \
  etc/dinit.d/boot.d/dinx-live-autologin \
  usr/local/libexec/dinx-live-autologin; do
  grep -Fq "/$live_path" <<<"$livefs_manifest" \
    || fail "missing livefs path: $live_path"
done
live_conf=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/artools/live.conf)
grep -Eq '^AUTOLOGIN=true$' <<<"$live_conf" \
  || fail 'livefs does not enable DINX autologin'
live_autologin=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/local/libexec/dinx-live-autologin)
grep -Fq 'command = "dbus-run-session /usr/local/libexec/dinx-aqueous-pearl"' <<<"$live_autologin" \
  || fail 'livefs autologin does not select Aqueous/Pearl'
grep -Fq 'user = "dinx"' <<<"$live_autologin" \
  || fail 'livefs autologin does not select the dinx user'
live_autologin_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/dinx-live-autologin)
grep -Fq 'command = /usr/local/libexec/dinx-live-autologin' <<<"$live_autologin_service" \
  || fail 'livefs autologin service command is incorrect'
grep -Fq 'before = greetd' <<<"$live_autologin_service" \
  || fail 'livefs autologin service does not precede greetd'

[scripts/check-iso-content.sh#6F7C]

[scripts/check-iso-content.sh#8974]

required_paths=(
  etc/calamares/branding/dinx/branding.desc
  etc/calamares/branding/dinx/stylesheet.qss
  etc/calamares/modules/packages.conf
  etc/calamares/modules/partition.conf
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
  etc/greetd/config.toml
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
  usr/bin/gamescope
  usr/bin/gamemoderun
  usr/bin/mangohud
  usr/bin/flatpak
  usr/bin/fwupdmgr
  usr/bin/vainfo
  usr/bin/scanimage
  usr/lib/libayatana-appindicator3.so.1
  usr/bin/kolourpaint
  usr/bin/steam
  etc/dinit.d/bluetoothd
  etc/dinit.d/root-ro
  etc/pearl/greeter.json
  usr/bin/pearl-greeter
  usr/lib/pearl/pearl-greeter-host
  usr/lib/pearl/pearl-greeter-session
  usr/lib/pearl/pearl-greeter-init
  usr/share/pearl-greeter/release-gate.json
  etc/profile.d/dinx.sh
  etc/default/useradd
  etc/fish/config.fish
  etc/skel/.bash_profile
  etc/skel/.config/gtk-3.0/settings.ini
  etc/skel/.config/gtk-4.0/settings.ini
  etc/skel/.config/dinx/theme.json
  etc/skel/.config/qt6ct/qt6ct.conf
  etc/skel/.config/qt6ct/colors/DINX.conf
  etc/skel/.config/swayimg/init.lua
  etc/skel/.config/topgrade.toml
  etc/skel/.bashrc
  etc/skel/.config/shikane/config.toml
  usr/share/themes/DINX/gtk-3.0/gtk.css
  usr/share/themes/DINX/gtk-4.0/gtk.css
  usr/share/themes/DINX/index.theme
  usr/share/themes/DINX/gtk-3.0/gtk-dark.css
  usr/share/themes/DINX/gtk-4.0/gtk-dark.css
  usr/bin/qt6ct
  usr/share/themes/adw-gtk3/gtk-3.0/gtk.css
  usr/share/themes/adw-gtk3/gtk-4.0/gtk.css
  usr/bin/foot
  usr/bin/aqueous
  usr/bin/aqueousctl
  usr/bin/aqueous-config
  usr/bin/pearl
  usr/share/dinx/theme/DINX.json
  usr/share/polkit-1/actions/org.aqueous.Pearl.Greeter.Appearance.policy
  usr/bin/phyto
  usr/bin/pori
  usr/local/libexec/pori-mount-service
  usr/bin/file-roller
  usr/bin/dome
  usr/bin/seafoam-settings
  usr/bin/zls
  usr/share/applications/org.aqueous.Dome.desktop
  usr/share/applications/seafoam-settings.desktop
  usr/share/icons/hicolor/scalable/apps/org.aqueous.Dome.svg
  usr/share/icons/hicolor/scalable/apps/org.seafoam.Settings.svg
  usr/share/metainfo/org.aqueous.Dome.metainfo.xml
  usr/share/licenses/seafoam-settings/LICENSE
  usr/share/licenses/zls/LICENSE
  usr/share/licenses/zls/zig-LICENSE
  usr/share/doc/seafoam-settings/README.md
  usr/share/doc/zls/README.md
  etc/zls.json
  etc/xdg/zls.json
  usr/lib/zls/zig-env
  usr/lib/zls/zig-env.zon
  usr/lib/zls/zig/std/std.zig
  usr/bin/gparted
  usr/bin/shikane
  usr/bin/shikanectl
  usr/bin/wdisplays
  usr/bin/fish
  usr/bin/nano
  usr/bin/ffmpeg
  usr/bin/btop
  usr/bin/dialog
  usr/bin/fzf
  usr/bin/glances
  usr/bin/info
  usr/bin/man
  usr/bin/sftp
  usr/bin/sqlite3
  usr/bin/tmux
  usr/bin/vim
  usr/bin/watch
  usr/bin/whiptail
  usr/share/kio/servicemenus/nocttyhere.desktop
  usr/lib/ssh/sftp-server
  usr/bin/nvtop
  usr/bin/zathura
  usr/bin/pwvucontrol
  usr/bin/blueman-manager
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
  usr/bin/vlc
  usr/bin/qvlc
  usr/bin/strawberry
  usr/bin/topgrade
  usr/bin/paru
  usr/bin/shelly
  usr/bin/shelly-ui
  usr/bin/shelly-key
  usr/bin/shelly-notifications
  usr/bin/shelly-flatpak-integrate
  usr/bin/cyan-skillfish-governor-smu
  usr/bin/bc250-control-center
  usr/bin/bc250-control-center-cli
  usr/bin/bc250-control-centerd
  etc/cyan-skillfish-governor-smu/config.toml
  etc/dinit.d/cyan-skillfish-governor-smu
  usr/local/libexec/dinx-cyan-skillfish-governor
  usr/lib/firmware/amdgpu/cyan_skillfish2_pfp.bin.zst
  usr/share/vulkan/icd.d/radeon_icd.json
  usr/libexec/bc250-control-center/bc250-package-maintenance
  usr/share/bc250-control-center/VERSION
  usr/share/applications/io.github.movacx.bc250-control-center.desktop
  usr/share/metainfo/io.github.movacx.bc250-control-center.metainfo.xml
  usr/share/polkit-1/actions/io.github.movacx.bc250-control-center.policy
  usr/share/icons/hicolor/256x256/apps/bc250-control-center.png
  usr/share/pixmaps/bc250-control-center.png
  usr/share/licenses/bc250-control-center/LICENSE
  usr/bin/vulkaninfo
  etc/paru.conf
  etc/shellybuild.conf
  usr/share/flatpak/remotes.d/flathub.flatpakrepo
  usr/share/applications/vlc.desktop
  usr/share/applications/org.strawberrymusicplayer.strawberry.desktop
  usr/share/applications/swayimg.desktop
  usr/share/applications/org.kde.kolourpaint.desktop
  usr/share/applications/com.shellyorg.shelly.desktop
  usr/share/applications/com.shellyorg.shelly-notifications.desktop
  usr/bin/ufw
  usr/bin/gufw
  usr/bin/qps
  usr/bin/opensnitchd
  usr/bin/opensnitch-ui
  etc/ufw/ufw.conf
  etc/dinit.d/ufw
  etc/dinit.d/opensnitchd
  usr/share/applications/gufw.desktop
  usr/share/applications/qps.desktop
  usr/share/applications/opensnitch_ui.desktop
  usr/share/icons/hicolor/scalable/apps/opensnitch-ui.svg
  usr/bin/wl-copy
  usr/bin/wl-paste
  usr/lib/bluetooth/bluetoothd
  usr/lib/zathura/libpdf-mupdf.so
  usr/share/applications/org.pwmt.zathura.desktop
  usr/share/applications/org.pwmt.zathura-pdf-mupdf.desktop
  usr/share/applications/com.saivert.pwvucontrol.desktop
  usr/bin/noctty
  usr/bin/nocted
  usr/bin/clangd
  usr/share/applications/com.noctty.NOCTTY.desktop
  usr/share/applications/com.noctty.NoctEd.desktop
  usr/share/icons/hicolor/scalable/apps/com.noctty.NOCTTY.svg
  usr/share/icons/hicolor/scalable/apps/com.noctty.NoctEd.svg
  usr/share/nocted/language-specs/zig.lang
  usr/share/nocted/language-specs/svelte.lang
  usr/share/nocted/language-specs/kof.lang
  usr/share/nocted/styles/nocted-dark.xml
  usr/share/nocted/styles/nocted-light.xml
  usr/bin/calamares
  usr/share/wayland-sessions/dinx-aqueous-pearl.desktop
  usr/local/libexec/dinx-idle
  usr/local/libexec/dinx-lock
  usr/local/libexec/dinx-aqueous-pearl
  usr/local/libexec/dinx-aqueous-init
  usr/local/libexec/dinx-session-supervisor
  usr/bin/dbus-send
  usr/bin/lxqt-policykit-agent
  usr/bin/ps
  usr/share/applications/dinx-installer.desktop
  usr/local/bin/dinx-save-shikane-profile
  usr/local/bin/dinx-wdisplays
  usr/bin/brightnessctl
  usr/bin/swayidle
  usr/bin/swaylock
  usr/share/applications/com.pori.app.desktop
  usr/share/applications/org.aqueous.Phyto.desktop
  usr/share/applications/org.gnome.FileRoller.desktop
  usr/share/applications/gparted.desktop
  usr/share/applications/network.cycles.wdisplays.desktop
  usr/share/grub/themes/artix/theme.txt
)

for path in "${required_paths[@]}"; do
  grep -Fq "/$path" <<<"$manifest" || fail "missing ISO path: $path"
done
if grep -Fq '/usr/share/wayland-sessions/labwc.desktop' <<<"$manifest"; then
  fail 'retired Labwc user session remains in the ISO payload'
fi
pearl_greeter_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/pearl/greeter.json)
grep -Fq '"theme": "gtk"' <<<"$pearl_greeter_config" || fail 'Pearl Greeter GTK theme is not enabled'
grep -Fq '"gtk_theme": "DINX"' <<<"$pearl_greeter_config" || fail 'Pearl Greeter DINX theme is not enabled'
grep -Fq '"force_session": "wayland:dinx-aqueous-pearl.desktop"' <<<"$pearl_greeter_config" \
  || fail 'Pearl Greeter does not force the DINX Aqueous/Pearl session'
grep -Fq '"allow": ["wayland:dinx-aqueous-pearl.desktop"]' <<<"$pearl_greeter_config" \
  || fail 'Pearl Greeter allows an unexpected user session'
grep -Fq '"allow_uwsm": false' <<<"$pearl_greeter_config" || fail 'Pearl Greeter UWSM integration is enabled'
grep -Fq '"x11": false' <<<"$pearl_greeter_config" || fail 'Pearl Greeter X11 integration is enabled'
if grep -Eiq 'systemd|systemctl' <<<"$pearl_greeter_config"; then
  fail 'Pearl Greeter config contains a systemd integration'
fi
pearl_release_gate=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/pearl-greeter/release-gate.json)
grep -Fq '"schema": 1' <<<"$pearl_release_gate" || fail 'Pearl Greeter release gate schema is missing'
grep -Fq '"activated_services": []' <<<"$pearl_release_gate" || fail 'Pearl Greeter release gate activates a service'
pearl_passwd=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/passwd)
grep -Eq '^pearl-greeter:' <<<"$pearl_passwd" || fail 'Pearl Greeter account is missing from the rootfs'
pearl_group=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/group)
grep -Eq '^pearl-greeter:' <<<"$pearl_group" || fail 'Pearl Greeter group is missing from the rootfs'
if grep -E '/var/lib/pacman/local/greetd-regreet-[^/]*/' <<<"$manifest"; then
  fail 'retired ReGreet package metadata is present'
fi
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
aqueous_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/wayland-sessions/dinx-aqueous-pearl.desktop)
grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-aqueous-pearl' <<<"$aqueous_session" || fail 'DINX Aqueous/Pearl session command is incorrect'
grep -Fq 'TryExec=/usr/local/libexec/dinx-aqueous-pearl' <<<"$aqueous_session" || fail 'DINX Aqueous/Pearl session TryExec is missing'
aqueous_launcher=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-aqueous-pearl)
aqueous_init=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-aqueous-init)
session_supervisor=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-session-supervisor)
grep -Fq 'exec /usr/bin/aqueous -c /usr/local/libexec/dinx-aqueous-init' <<<"$aqueous_launcher" || fail 'DINX Aqueous wrapper does not launch the direct init child'
grep -Fq 'LIBSEAT_BACKEND="${LIBSEAT_BACKEND:-logind}"' <<<"$aqueous_launcher" || fail 'DINX Aqueous wrapper does not select the elogind/libseat backend'
grep -Fq 'WLR_RENDERER_ALLOW_SOFTWARE=1' <<<"$aqueous_launcher" || fail 'DINX Aqueous software-render fallback is missing'
grep -Fq 'exec /usr/local/libexec/dinx-session-supervisor aqueous' <<<"$aqueous_init" || fail 'DINX Aqueous init does not launch the supervisor'
grep -Fq 'start_required shell pearl' <<<"$session_supervisor" || fail 'DINX Aqueous supervisor does not launch Pearl'
grep -Fq 'wait_for_wayland' <<<"$session_supervisor" || fail 'DINX session supervisor does not gate Wayland readiness'
grep -Fq 'wait_for_dbus' <<<"$session_supervisor" || fail 'DINX session supervisor does not gate D-Bus readiness'
if grep -Eq 'systemd|systemctl|uwsm|loginctl' <<<"$aqueous_session$aqueous_launcher$aqueous_init$session_supervisor"; then
  fail 'DINX Aqueous/Pearl session contains a forbidden systemd or uwsm integration'
fi


session_entries=$(grep -oE '/usr/share/(wayland-sessions|xsessions)/[^[:space:]]+\.desktop' <<<"$manifest" | sort -u || true)
while IFS= read -r session_path; do
  [[ -n "$session_path" ]] || continue
  case "$session_path" in
    /usr/share/wayland-sessions/dinx-aqueous-pearl.desktop) continue ;;
    /usr/share/wayland-sessions/dinx-gaming.desktop) ;;
    *) fail "unsupported user session remains: $session_path" ;;
  esac
  session_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" "${session_path#/}")
  grep -Fq 'Hidden=true' <<<"$session_config" \
    || fail "non-Aqueous session remains visible: $session_path"
  grep -Fq 'NoDisplay=true' <<<"$session_config" \
    || fail "non-Aqueous session remains discoverable: $session_path"
done <<<"$session_entries"


grub_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/grub/themes/artix/theme.txt)
grep -Fq 'DINX GRUB theme override.' <<<"$grub_theme" || fail 'DINX GRUB theme override is missing'
if grep -Eq '^[[:space:]]*(menu_pixmap_style|selected_item_pixmap_style)[[:space:]]*=' <<<"$grub_theme"; then
  fail 'DINX GRUB theme still enables opaque menu textures'
fi
grep -Fq 'desktop-color: "#0b0d12"' <<<"$grub_theme" || fail 'DINX GRUB background color is missing'
grep -Fq 'selected_item_color = "#8fb8ff"' <<<"$grub_theme" || fail 'DINX GRUB accent color is missing'

root_greetd_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/greetd/config.toml)
grep -Fq '[general]' <<<"$root_greetd_config" || fail 'installed greetd general section is missing'
grep -Fq 'source_profile = false' <<<"$root_greetd_config" || fail 'installed greetd sources the greeter profile'
grep -Fq 'command = "/usr/lib/pearl/pearl-greeter-host"' <<<"$root_greetd_config" \
  || fail 'installed greetd does not launch Pearl Greeter'
grep -Fq 'user = "pearl-greeter"' <<<"$root_greetd_config" \
  || fail 'installed greetd does not use the Pearl Greeter account'
if grep -Fq '[initial_session]' <<<"$root_greetd_config"; then
  fail 'installed greetd unexpectedly enables live autologin'
fi
if grep -Eiq 'systemd|systemctl' <<<"$root_greetd_config"; then
  fail 'installed greetd config contains a systemd integration'
fi

grep -Fq '/usr/share/applications/swayimg.desktop' <<<"$manifest" || fail 'Swayimg desktop entry is not in the ISO payload'
grep -Fq 'vlc.desktop' <<<"$manifest" || fail 'VLC desktop entry is not in the ISO payload'
grep -Fq 'org.strawberrymusicplayer.strawberry.desktop' <<<"$manifest" || fail 'Strawberry desktop entry is not in the ISO payload'
grep -Fq 'com.shellyorg.shelly.desktop' <<<"$manifest" || fail 'Shelly desktop entry is not in the ISO payload'
theme_json=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/dinx/theme/DINX.json)
grep -Fq '"mSurface": "#0b0d12"' <<<"$theme_json" || fail 'DINX surface palette is missing'
grep -Fq '"mPrimary": "#8fb8ff"' <<<"$theme_json" || fail 'DINX primary palette is missing'
gtk3_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/gtk-3.0/settings.ini)
grep -Fq 'gtk-font-name=Noto Sans 10' <<<"$gtk3_settings" || fail 'GTK3 Noto Sans font contract is missing'
gtk4_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/gtk-4.0/settings.ini)
grep -Fq 'gtk-font-name=Noto Sans 10' <<<"$gtk4_settings" || fail 'GTK4 Noto Sans font contract is missing'
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
grep -Fq 'general="Noto Sans,10' <<<"$qt6ct_config" || fail 'Qt6ct Noto Sans font contract is missing'
swayimg_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/swayimg/init.lua)
grep -Fq 'swayimg.gallery.window_color = 0xff0b0d12' <<<"$swayimg_config" || fail 'DINX Swayimg surface is missing'
grep -Fq 'swayimg.text.font = "Noto Sans"' <<<"$swayimg_config" || fail 'Swayimg font contract is missing'
grep -Fq 'swayimg.text.size = 10' <<<"$swayimg_config" || fail 'Swayimg text size does not match Noto Sans 10'
gtk_index=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/index.theme)
grep -Fq 'Name=DINX' <<<"$gtk_index" || fail 'DINX GTK theme index is missing'
grep -Fq 'IconTheme=Adwaita' <<<"$gtk_index" || fail 'DINX icon theme bridge is missing'
gtk3_dark_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-3.0/gtk-dark.css)
grep -Fqx '@import url("gtk.css");' <<<"$gtk3_dark_theme" || fail 'DINX GTK3 dark bridge is missing'
gtk4_dark_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-4.0/gtk-dark.css)
grep -Fqx '@import url("gtk.css");' <<<"$gtk4_dark_theme" || fail 'DINX GTK4 dark bridge is missing'

ufw_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/ufw/ufw.conf)
grep -Fq 'ENABLED=no' <<<"$ufw_config" || fail 'UFW is not disabled by default for safe manual configuration'
for disabled_service in ufw opensnitchd; do
  if grep -Fq "/etc/dinit.d/boot.d/$disabled_service" <<<"$manifest"; then
    fail "firewall service is enabled by default: $disabled_service"
  fi
done
governor_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/cyan-skillfish-governor-smu/config.toml)
grep -Fq '[gpu]' <<<"$governor_config" || fail 'Cyan Skillfish governor GPU section is missing'
grep -Fq 'set-method = "smu"' <<<"$governor_config" || fail 'Cyan Skillfish governor is not configured for SMU control'
grep -Fq 'min = 1000' <<<"$governor_config" || fail 'Cyan Skillfish governor minimum frequency is not configured'
grep -Fq 'max = 1850' <<<"$governor_config" || fail 'Cyan Skillfish governor maximum frequency is not configured'
grep -Fq '/etc/dinit.d/boot.d/cyan-skillfish-governor-smu' <<<"$manifest" || fail 'Cyan Skillfish governor is not enabled in the rootfs dinit boot set'
topgrade_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/topgrade.toml)
grep -Fq 'arch_package_manager = "pacman"' <<<"$topgrade_config" || fail 'Topgrade is not pinned to Artix pacman'

aqueous_wrapper=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-aqueous-pearl)
grep -Fq 'exec /usr/bin/aqueous -c /usr/local/libexec/dinx-aqueous-init' <<<"$aqueous_wrapper" || fail 'Aqueous session command is incorrect'
aqueous_init=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-aqueous-init)
grep -Fq 'exec /usr/local/libexec/dinx-session-supervisor aqueous' <<<"$aqueous_init" || fail 'Aqueous init supervisor command is missing'
session_supervisor=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-session-supervisor)
grep -Fq 'start_required shell pearl' <<<"$session_supervisor" || fail 'Pearl is not required by the session supervisor'
grep -Fq 'wait_for_wayland' <<<"$session_supervisor" || fail 'Aqueous session does not gate Wayland readiness'
grep -Fq 'wait_for_dbus' <<<"$session_supervisor" || fail 'Aqueous session does not gate D-Bus readiness'
if grep -Eiq 'labwc|noctalia|systemd|uwsm' <<<"$aqueous_wrapper
$aqueous_init
$session_supervisor"; then
  fail 'Aqueous/Pearl session contains a retired session or init integration'
fi
idle_wrapper=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-idle)
grep -Fq 'timeout 600 /usr/local/libexec/dinx-lock' <<<"$idle_wrapper" || fail 'DINX idle manager lock timeout is missing'
grep -Fq 'before-sleep /usr/local/libexec/dinx-lock' <<<"$idle_wrapper" || fail 'DINX idle manager lock-before-suspend hook is missing'
lock_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinx-lock.desktop)
grep -Fq 'Exec=/usr/local/libexec/dinx-lock' <<<"$lock_desktop" || fail 'DINX lock launcher is missing'
shell_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/profile.d/dinx.sh)
grep -Fq 'TERMINAL=' <<<"$shell_config" || fail 'DINX shell terminal default is missing'
grep -Fq 'EDITOR=' <<<"$shell_config" || fail 'DINX shell editor default is missing'
grep -Fq 'QT_QPA_PLATFORMTHEME=' <<<"$shell_config" || fail 'Qt6ct session integration is missing'
grep -Fq 'DINX_COLOR_SCHEME=' <<<"$shell_config" || fail 'DINX color scheme session integration is missing'
grep -Fq 'export SHELL=/bin/fish' <<<"$shell_config" || fail 'DINX POSIX shell default is not Fish'
fish_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/fish/config.fish)
grep -Fq 'set -gx SHELL /bin/fish' <<<"$fish_config" || fail 'DINX Fish shell default is missing'
useradd_defaults=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/default/useradd)
grep -Fq 'SHELL=/bin/fish' <<<"$useradd_defaults" || fail 'new-user shell default is not Fish'
users_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/users.conf)
grep -Fq 'shell: /bin/fish' <<<"$users_config" || fail 'Calamares user shell is not Fish'
mimeapps_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/xdg/mimeapps.list)
grep -Fq 'inode/directory=org.aqueous.Phyto.desktop;' <<<"$mimeapps_config" || fail 'Phyto is not the default directory handler'
grep -Fq 'text/html=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTML handler'
grep -Fq 'x-scheme-handler/http=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTTP handler'
grep -Fq 'x-scheme-handler/https=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTTPS handler'
grep -Fq 'application/pdf=org.pwmt.zathura.desktop;' <<<"$mimeapps_config" || fail 'Zathura is not the default PDF handler'
grep -Fq 'image/png=swayimg.desktop;' <<<"$mimeapps_config" || fail 'Swayimg is not the default PNG handler'
grep -Fq 'video/mp4=vlc.desktop;' <<<"$mimeapps_config" || fail 'VLC is not the default MP4 handler'
grep -Fq 'audio/flac=org.strawberrymusicplayer.strawberry.desktop;' <<<"$mimeapps_config" || fail 'Strawberry is not the default FLAC handler'
for archive_mime in application/zip application/x-7z-compressed application/vnd.rar application/x-tar application/gzip application/x-bzip2 application/x-xz application/zstd; do
  grep -Fq "$archive_mime=org.gnome.FileRoller.desktop;" <<<"$mimeapps_config" || fail "File Roller is not the default archive handler for $archive_mime"
done

# Artix desktop packages may ship inert compatibility unit files; reject the init/runtime itself.
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
  if forbidden_matches=$(grep -F "/$forbidden_path" <<<"$manifest"); then
    printf '%s\n' "$forbidden_matches" >&2
    fail "forbidden desktop/runtime payload is present: $forbidden_path"
  fi
done
if forbidden_matches=$(grep -E '/var/lib/pacman/local/(gvfs|gvfs-gphoto2|gvfs-mtp|gvfs-smb|partitionmanager|thunar|thunar-archive-plugin|thunar-volman|tumbler)-[^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'removed file-manager, volume-mounter or partition-manager package metadata is present'
fi
if forbidden_matches=$(grep -E '/var/lib/pacman/local/(labwc|noctalia)-[^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'retired Labwc/Noctalia package metadata is present'
fi
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
  fail 'uwsm package metadata is present; the DINX Aqueous/Pearl path is direct'
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
  if forbidden_matches=$(grep -F "/$forbidden_path" <<<"$livefs_manifest"); then
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


calamares_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/settings.conf)
grep -Fq 'branding: dinx' <<<"$calamares_settings" || fail 'DINX Calamares branding is not selected'
grep -Fq 'services-artix' <<<"$calamares_settings" || fail 'Calamares dinit service module is not selected'
grep -Fq 'postcfg' <<<"$calamares_settings" || fail 'Calamares dinit user-service module is not selected'
calamares_services=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/services-artix.conf)
calamares_mount=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/mount.conf)
calamares_bootloader=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/modules/bootloader.conf)
grub_windows=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/default/grub.d/40-dinx-windows.cfg)
grep -Fq 'subvolume: ""' <<<"$calamares_mount" || fail 'Calamares Btrfs existing-subvolume guard is missing'
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

installer_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinx-installer.desktop)
grep -Fq 'Exec=pkexec calamares' <<<"$installer_desktop" || fail 'DINX installer launcher is missing'
bc250_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/io.github.movacx.bc250-control-center.desktop)
grep -Fq 'Exec=bc250-control-center' <<<"$bc250_desktop" || fail 'BC250 Control Center desktop launcher command is incorrect'
grep -Fq 'Icon=bc250-control-center' <<<"$bc250_desktop" || fail 'BC250 Control Center desktop icon is missing'
noctty_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/com.noctty.NOCTTY.desktop)
grep -Fq 'TryExec=noctty' <<<"$noctty_desktop" || fail 'NOCTTY desktop launcher is missing'
grep -Fq 'Exec=noctty --open-uri %u' <<<"$noctty_desktop" || fail 'NOCTTY desktop command is incorrect'

nocted_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/com.noctty.NoctEd.desktop)
grep -Fq 'Exec=nocted %F' <<<"$nocted_desktop" || fail 'NoctEd desktop launcher is missing'
grep -Fq 'Icon=com.noctty.NoctEd' <<<"$nocted_desktop" || fail 'NoctEd desktop icon is missing'
dinitui_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinitui.desktop)
grep -Fq 'Exec=dinitui' <<<"$dinitui_desktop" || fail 'DinitUI desktop launcher is missing'
grep -Fq 'Icon=org.dinx.DinitUI' <<<"$dinitui_desktop" || fail 'DinitUI desktop icon contract is missing'
dinxpanel_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinxpanel.desktop)
grep -Fq 'Exec=dinxpanel' <<<"$dinxpanel_desktop" || fail 'DINXPanel desktop launcher is missing'
grep -Fq 'Icon=org.dinx.DinxPanel' <<<"$dinxpanel_desktop" || fail 'DINXPanel desktop icon contract is missing'
dome_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/org.aqueous.Dome.desktop)
grep -Fq 'Exec=dome' <<<"$dome_desktop" || fail 'Dome desktop launcher is missing'
grep -Fq 'Icon=org.aqueous.Dome' <<<"$dome_desktop" || fail 'Dome desktop icon contract is missing'
settings_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/seafoam-settings.desktop)
grep -Fq 'Exec=seafoam-settings' <<<"$settings_desktop" || fail 'Seafoam Settings desktop launcher is missing'
grep -Fq 'Icon=org.seafoam.Settings' <<<"$settings_desktop" || fail 'Seafoam Settings desktop icon contract is missing'
zls_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/zls.json)
zls_xdg_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/xdg/zls.json)
[[ "$zls_config" == "$zls_xdg_config" ]] || fail 'ZLS XDG configuration alias is not identical'
grep -Fq '"zig_exe_path": "/usr/lib/zls/zig-env"' <<<"$zls_config" || fail 'ZLS Zig executable configuration is missing'
grep -Fq '"zig_lib_path": "/usr/lib/zls/zig"' <<<"$zls_config" || fail 'ZLS Zig library configuration is missing'
zls_shim=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/lib/zls/zig-env)
grep -Fq 'case "${1:-}" in' <<<"$zls_shim" || fail 'ZLS Zig shim command contract is missing'
grep -Fq '/usr/bin/zig' <<<"$zls_shim" || fail 'ZLS Zig shim compiler delegation is missing'
grep -Fq 'printf '\''%s\n'\'' 0.16.0' <<<"$zls_shim" || fail 'ZLS Zig shim version contract is missing'
grep -Fq '/usr/bin/dinitui' <<<"$manifest" || fail 'DinitUI executable is missing'
grep -Fq '/usr/bin/dinxpanel' <<<"$manifest" || fail 'DINXPanel executable is missing'
grep -Fq '/usr/share/icons/hicolor/scalable/apps/org.dinx.DinitUI.svg' <<<"$manifest" || fail 'DinitUI icon is missing'
grep -Fq '/usr/share/icons/hicolor/scalable/apps/org.dinx.DinxPanel.svg' <<<"$manifest" || fail 'DINXPanel icon is missing'
grep -Fq '/usr/bin/clangd' <<<"$manifest" || fail 'clangd runtime is missing'
grep -Fq '/usr/share/nocted/styles/nocted-light.xml' <<<"$manifest" || fail 'NoctEd light scheme is missing'


livefs_required_paths=(
  etc/artools/live.conf
  etc/dinit.d/boot.d/NetworkManager
  etc/dinit.d/boot.d/artix-live
  etc/dinit.d/boot.d/cyan-skillfish-governor-smu
  etc/dinit.d/boot.d/dinx-live-autologin
  etc/dinit.d/dinx-live-autologin
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
grep -Fq 'AUTOLOGIN=true' <<<"$live_config" || fail 'live session autologin is not enabled'
grep -Fq 'LIVEUSER=dinx' <<<"$live_config" || fail 'live session user is not dinx'

live_autologin_wrapper=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" usr/local/libexec/dinx-live-autologin)
grep -Fq '[initial_session]' <<<"$live_autologin_wrapper" || fail 'live autologin initial session is missing'
grep -Fq 'command = "dbus-run-session /usr/local/libexec/dinx-aqueous-pearl"' <<<"$live_autologin_wrapper" || fail 'live autologin command is incorrect'
grep -Fq 'user = "dinx"' <<<"$live_autologin_wrapper" || fail 'live autologin user is incorrect'
live_autologin_service=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/dinit.d/dinx-live-autologin)
grep -Fq 'before = greetd' <<<"$live_autologin_service" || fail 'live autologin service does not precede greetd'

live_passwd=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/passwd)
grep -Eq '^dinx:' <<<"$live_passwd" || fail 'live session user dinx is missing'

printf 'ISO content check passed: Aqueous/Pearl sole user session, Pearl shell, direct Pearl Greeter host under greetd, no systemd/UWSM or legacy X11, hidden manual DINX Gaming launcher, Noctty terminal contract, Firefox default with pro-user policy, BC250 Control Center with supervised Aqueous/Pearl helper, AMDGPU firmware/RADV/Vulkan diagnostics and Cyan Skillfish governor, btop/nvtop/inxi diagnostics, Zathura PDF and Swayimg image handlers, KolourPaint image editing, SANE scanner backend, fwupd firmware tooling, Flatpak runtime, File Roller archive actions, GParted partition editing, wdisplays display configuration, shikane deterministic output profiles, VLC video playback, Strawberry music playback, pwvucontrol audio mixer, topgrade/paru/Shelly package management, UFW/Gufw and OpenSnitch firewall tools, Qps process manager, NetworkManager/nm-connection-editor, BlueZ/Blueman/UPower, Pori dinit storage management, Phyto file management, kernel ntfs3 live read/write support, optional legacy ntfs-3g post-install support, CLI recovery and transfer tools, Nano and dinit payloads.\n'
