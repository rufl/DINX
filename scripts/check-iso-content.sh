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
  usr/local/bin/dinx-alpha7-hardware-report
  usr/share/wayland-sessions/dinx-gaming.desktop
  usr/bin/gamescope
  usr/bin/gamemoderun
  usr/bin/mangohud
  usr/bin/vainfo
  usr/lib/libayatana-appindicator3.so.1
  usr/bin/steam
  etc/dinit.d/bluetoothd
  etc/dinit.d/root-ro
  etc/greetd/regreet.toml
  etc/mango/dinx.conf
  etc/mango/greeter.conf
  etc/profile.d/dinx.sh
  etc/skel/.bash_profile
  etc/skel/.config/gtk-3.0/settings.ini
  etc/skel/.config/gtk-4.0/settings.ini
  etc/skel/.config/mango/config.conf
  etc/skel/.config/noctalia/config.toml
  etc/skel/.config/noctalia/palettes/DINX.json
  etc/skel/.config/qt6ct/qt6ct.conf
  etc/skel/.config/swayimg/init.lua
  etc/skel/.config/topgrade.toml
  etc/skel/.bashrc
  usr/share/themes/DINX/gtk-3.0/gtk.css
  usr/share/themes/DINX/gtk-4.0/gtk.css
  usr/share/themes/DINX/index.theme
  usr/share/themes/DINX/gtk-3.0/gtk-dark.css
  usr/share/themes/DINX/gtk-4.0/gtk-dark.css
  usr/bin/qt6ct
  usr/share/themes/adw-gtk3/gtk-3.0/gtk.css
  usr/share/themes/adw-gtk3/gtk-4.0/gtk.css
  usr/bin/foot
  usr/bin/file-roller
  usr/bin/nano
  usr/bin/firefox
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
  usr/share/noctty/noctalia/noctalia-v5-widget.toml
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
  usr/share/applications/vlc.desktop
  usr/share/applications/org.strawberrymusicplayer.strawberry.desktop
  usr/share/applications/swayimg.desktop
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
  usr/bin/mango
  usr/bin/mmsg
  usr/bin/noctalia
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
  usr/bin/partitionmanager
  usr/share/wayland-sessions/mango.desktop
  usr/bin/regreet
  usr/local/libexec/dinx-regreet
  usr/local/libexec/dinx-idle
  usr/local/libexec/dinx-lock
  usr/local/libexec/dinx-mango
  usr/share/applications/dinx-installer.desktop
  usr/bin/brightnessctl
  usr/bin/swayidle
  usr/bin/swaylock
  usr/share/applications/org.kde.partitionmanager.desktop
  usr/share/applications/org.gnome.FileRoller.desktop
  usr/share/grub/themes/artix/theme.txt
  usr/share/xdg-desktop-portal/mango-portals.conf
)

for path in "${required_paths[@]}"; do
  grep -Fq "/$path" <<<"$manifest" || fail "missing ISO path: $path"
done
gaming_launcher=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-gaming)
grep -Fq 'dinitui --gaming-enter' <<<"$gaming_launcher" || fail 'DINX gaming launcher does not enter the Gaming profile'
grep -Fq 'gamescope --backend drm --steam --fullscreen -- steam -tenfoot' <<<"$gaming_launcher" || fail 'DINX gaming launcher command is incorrect'
grep -Fq 'dinitui --gaming-leave' <<<"$gaming_launcher" || fail 'DINX gaming launcher does not restore the previous profile'
if grep -Eq 'systemctl|/bin/sh -c|dbus-daemon' <<<"$gaming_launcher"; then
  fail 'DINX gaming launcher contains a forbidden init or shell indirection'
fi
gaming_session=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/wayland-sessions/dinx-gaming.desktop)
grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-gaming' <<<"$gaming_session" || fail 'DINX gaming session command is incorrect'
grep -Fq 'TryExec=/usr/local/libexec/dinx-gaming' <<<"$gaming_session" || fail 'DINX gaming session TryExec is missing'

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
grep -Fq 'desktop-color: "#0b0d12"' <<<"$grub_theme" || fail 'DINX GRUB background color is missing'
grep -Fq 'selected_item_color = "#8fb8ff"' <<<"$grub_theme" || fail 'DINX GRUB accent color is missing'

regreet_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/greetd/regreet.toml)
grep -Fq 'application_prefer_dark_theme = true' <<<"$regreet_config" || fail 'ReGreet dark mode is not enabled'
grep -Fq 'theme_name = "DINX"' <<<"$regreet_config" || fail 'ReGreet DINX theme is not enabled'
grep -Fq 'font_name = "Cantarell 11"' <<<"$regreet_config" || fail 'ReGreet font contract is missing'

noctalia_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/noctalia/config.toml)
grep -Fq 'mode = "dark"' <<<"$noctalia_config" || fail 'Noctalia dark mode is not enabled'
grep -Fq '[shell.animation]' <<<"$noctalia_config" || fail 'Noctalia animation defaults are missing'
grep -Fq 'enabled = false' <<<"$noctalia_config" || fail 'Noctalia animations are not disabled by default'
grep -Fq 'settings_window_translucent = false' <<<"$noctalia_config" || fail 'Noctalia Settings transparency is not disabled by default'
grep -Fq '[shell.panel]' <<<"$noctalia_config" || fail 'Noctalia panel defaults are missing'
grep -Fq 'transparency_mode = "solid"' <<<"$noctalia_config" || fail 'Noctalia panel transparency is not disabled by default'
grep -Fq '[bar]' <<<"$noctalia_config" || fail 'Noctalia bar defaults are missing'
grep -Fq 'order = ["main"]' <<<"$noctalia_config" || fail 'Noctalia main bar is not first in creation order'
grep -Fq '[bar.main]' <<<"$noctalia_config" || fail 'Noctalia main bar is not configured'
grep -Fq 'position = "top"' <<<"$noctalia_config" || fail 'Noctalia main bar is not at the top'
grep -Fq 'reserve_space = true' <<<"$noctalia_config" || fail 'Noctalia main bar does not reserve space'
grep -Fq 'start = ["launcher", "workspaces"]' <<<"$noctalia_config" || fail 'Noctalia main bar launcher/workspace widgets are missing'
grep -Fq 'end = ["screenshot", "clipboard", "tray", "network"' <<<"$noctalia_config" || fail 'Noctalia status tray widget is missing'
grep -Fq '[widget.tray]' <<<"$noctalia_config" || fail 'Noctalia tray widget settings are missing'
grep -Fq '[shell.screenshot]' <<<"$noctalia_config" || fail 'Noctalia screenshot shell defaults are missing'
grep -Fq 'copy_to_clipboard = true' <<<"$noctalia_config" || fail 'Noctalia screenshots are not copied to the clipboard'
grep -Fq '/usr/share/applications/swayimg.desktop' <<<"$manifest" || fail 'Swayimg desktop entry is not in the ISO payload'
grep -Fq 'vlc.desktop' <<<"$manifest" || fail 'VLC desktop entry is not in the ISO payload'
grep -Fq 'org.strawberrymusicplayer.strawberry.desktop' <<<"$manifest" || fail 'Strawberry desktop entry is not in the ISO payload'
grep -Fq 'com.shellyorg.shelly.desktop' <<<"$manifest" || fail 'Shelly desktop entry is not in the ISO payload'
grep -Fq 'pinned = ["firefox", "dinxpanel", "dinitui"' <<<"$noctalia_config" || fail 'Noctalia dock does not establish the DINX primary hierarchy'
for specialist in gufw qps opensnitch_ui nm-connection-editor blueman-manager com.shellyorg.shelly; do
  if grep -Fq "\"$specialist\"" <<<"$noctalia_config"; then
    fail "specialist launcher remains pinned in the Noctalia dock: $specialist"
  fi
done
noctalia_palette=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/noctalia/palettes/DINX.json)
grep -Fq '"mSurface": "#0b0d12"' <<<"$noctalia_palette" || fail 'DINX Noctalia surface palette is missing'
grep -Fq '"mPrimary": "#8fb8ff"' <<<"$noctalia_palette" || fail 'DINX Noctalia primary palette is missing'
gtk3_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/gtk-3.0/settings.ini)
grep -Fq 'gtk-font-name=Cantarell 11' <<<"$gtk3_settings" || fail 'GTK3 Cantarell font contract is missing'
gtk4_settings=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/gtk-4.0/settings.ini)
grep -Fq 'gtk-font-name=Cantarell 11' <<<"$gtk4_settings" || fail 'GTK4 Cantarell font contract is missing'
grep -Fq 'builtin_ids = ["btop", "foot", "ghostty", "gtk3", "gtk4", "kcolorscheme", "mango", "qt"]' <<<"$noctalia_config" || fail 'Noctalia application templates are missing'
gtk3_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-3.0/gtk.css)
grep -Fq 'background-color: #0b0d12' <<<"$gtk3_theme" || fail 'DINX GTK3 surface is missing'
grep -Fq 'background-color: #8fb8ff' <<<"$gtk3_theme" || fail 'DINX GTK3 accent is missing'
grep -Fq 'font-family: Cantarell;' <<<"$gtk3_theme" || fail 'DINX GTK3 font family is missing'
grep -Fq 'font-size: 11pt;' <<<"$gtk3_theme" || fail 'DINX GTK3 font size is missing'
grep -Fq 'background-color: #11151d' <<<"$gtk3_theme" || fail 'DINX GTK3 control surface is missing'
grep -Fq 'background-color: #263249' <<<"$gtk3_theme" || fail 'DINX GTK3 hover state is missing'
if grep -Eq '#(31415d|151923|2859a8)' <<<"$gtk3_theme"; then
  fail 'DINX GTK3 contains an out-of-contract color'
fi
gtk4_theme=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/themes/DINX/gtk-4.0/gtk.css)
grep -Fq 'background-color: #0b0d12' <<<"$gtk4_theme" || fail 'DINX GTK4 surface is missing'
grep -Fq 'background-color: #8fb8ff' <<<"$gtk4_theme" || fail 'DINX GTK4 accent is missing'
grep -Fq 'font-family: Cantarell;' <<<"$gtk4_theme" || fail 'DINX GTK4 font family is missing'
grep -Fq 'font-size: 11pt;' <<<"$gtk4_theme" || fail 'DINX GTK4 font size is missing'
grep -Fq 'background-color: #11151d' <<<"$gtk4_theme" || fail 'DINX GTK4 control surface is missing'
grep -Fq 'background-color: #263249' <<<"$gtk4_theme" || fail 'DINX GTK4 hover state is missing'
if grep -Eq '#(31415d|151923|2859a8)' <<<"$gtk4_theme"; then
  fail 'DINX GTK4 contains an out-of-contract color'
fi
calamares_stylesheet=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/calamares/branding/dinx/stylesheet.qss)
grep -Fq 'font-family: Cantarell;' <<<"$calamares_stylesheet" || fail 'Calamares font family is missing'
grep -Fq 'font-size: 11pt;' <<<"$calamares_stylesheet" || fail 'Calamares font size is missing'
grep -Fq 'border-radius: 0' <<<"$calamares_stylesheet" || fail 'Calamares geometry contract is missing'
if grep -Eq 'border-radius: [1-9]|#(31415d|151923|2859a8)' <<<"$calamares_stylesheet"; then
  fail 'Calamares contains an out-of-contract geometry or color'
fi
qt6ct_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/qt6ct/qt6ct.conf)
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/noctalia.conf' <<<"$qt6ct_config" || fail 'Qt6ct Noctalia color path is missing'
grep -Fq 'general="Cantarell,11' <<<"$qt6ct_config" || fail 'Qt6ct Cantarell font contract is missing'
swayimg_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/swayimg/init.lua)
grep -Fq 'swayimg.gallery.window_color = 0xff0b0d12' <<<"$swayimg_config" || fail 'DINX Swayimg surface is missing'
grep -Fq 'swayimg.text.font = "Cantarell"' <<<"$swayimg_config" || fail 'Swayimg font contract is missing'
grep -Fq 'swayimg.text.size = 11' <<<"$swayimg_config" || fail 'Swayimg text size does not match Cantarell 11'
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

mango_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/mango/dinx.conf)
grep -Fq 'tag_num=2' <<<"$mango_config" || fail 'Mango does not start with two virtual desktops'
grep -Fq 'env=TERMINAL,dinx-terminal' <<<"$mango_config" || fail 'Mango does not expose the DINX terminal contract'
grep -Fq 'source_optional=~/.config/mango/config.conf' <<<"$mango_config" || fail 'Mango user workspace override is not enabled'
grep -Fq 'exec_once=lxqt-policykit-agent' <<<"$mango_config" || fail 'Mango does not start the PolicyKit authentication agent'
grep -Fq 'exec_once=bc250-control-centerd' <<<"$mango_config" || fail 'Mango does not autostart the BC250 user daemon'
grep -Fq 'exec_once=thunar --daemon' <<<"$mango_config" || fail 'Mango does not start the Thunar volume monitor'
grep -Fq 'bind=SUPER,Return,spawn,dinx-terminal' <<<"$mango_config" || fail 'Mango terminal shortcut is missing'
grep -Fq 'tagrule=id:*,open_as_floating:1' <<<"$mango_config" || fail 'Mango does not open new windows floating'
grep -Fq 'bind=SUPER,space,togglefloating,' <<<"$mango_config" || fail 'Mango floating toggle shortcut is missing'
grep -Fq 'exec_once=/usr/local/libexec/dinx-idle' <<<"$mango_config" || fail 'Mango does not start the DINX idle manager'
grep -Fq 'bind=SUPER,l,spawn,/usr/local/libexec/dinx-lock' <<<"$mango_config" || fail 'Mango lock shortcut is missing'
grep -Fq 'bind=XF86MonBrightnessDown,spawn,brightnessctl set 5%-' <<<"$mango_config" || fail 'Mango brightness-down shortcut is missing'
grep -Fq 'bind=XF86MonBrightnessUp,spawn,brightnessctl set 5%+' <<<"$mango_config" || fail 'Mango brightness-up shortcut is missing'
idle_wrapper=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/local/libexec/dinx-idle)
grep -Fq 'timeout 600 /usr/local/libexec/dinx-lock' <<<"$idle_wrapper" || fail 'DINX idle manager lock timeout is missing'
grep -Fq 'before-sleep /usr/local/libexec/dinx-lock' <<<"$idle_wrapper" || fail 'DINX idle manager lock-before-suspend hook is missing'
lock_desktop=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" usr/share/applications/dinx-lock.desktop)
grep -Fq 'Exec=/usr/local/libexec/dinx-lock' <<<"$lock_desktop" || fail 'DINX lock launcher is missing'
shell_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/profile.d/dinx.sh)
grep -Fq 'TERMINAL=' <<<"$shell_config" || fail 'DINX shell terminal default is missing'
grep -Fq 'EDITOR=' <<<"$shell_config" || fail 'DINX shell editor default is missing'
grep -Fq 'QT_QPA_PLATFORMTHEME=' <<<"$shell_config" || fail 'Qt6ct session integration is missing'
grep -Fq 'NOCTALIA_COLOR_SCHEME=' <<<"$shell_config" || fail 'Noctalia color scheme session integration is missing'
mimeapps_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/xdg/mimeapps.list)
grep -Fq 'inode/directory=thunar.desktop;' <<<"$mimeapps_config" || fail 'Thunar is not the default directory handler'
grep -Fq 'text/html=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTML handler'
grep -Fq 'x-scheme-handler/http=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTTP handler'
grep -Fq 'x-scheme-handler/https=firefox.desktop;' <<<"$mimeapps_config" || fail 'Firefox is not the default HTTPS handler'
grep -Fq 'application/pdf=org.pwmt.zathura.desktop;' <<<"$mimeapps_config" || fail 'Zathura is not the default PDF handler'
grep -Fq 'image/png=swayimg.desktop;' <<<"$mimeapps_config" || fail 'Swayimg is not the default PNG handler'
grep -Fq 'video/mp4=vlc.desktop;' <<<"$mimeapps_config" || fail 'VLC is not the default MP4 handler'
grep -Fq 'audio/flac=org.strawberrymusicplayer.strawberry.desktop;' <<<"$mimeapps_config" || fail 'Strawberry is not the default FLAC handler'

# Artix desktop packages may ship inert compatibility unit files; reject the init/runtime itself.
for forbidden_path in \
  etc/systemd \
  usr/lib/systemd/systemd \
  usr/lib/systemd/user/bc250-control-centerd.service \
  usr/lib/systemd/system/cyan-skillfish-governor-smu.service.d/91-bc250-control-center-overlay-preflight.conf \
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
if forbidden_matches=$(grep -E '/var/lib/pacman/local/systemd-[0-9][^/]*/' <<<"$manifest"); then
  printf '%s\n' "$forbidden_matches" >&2
  fail 'systemd init package metadata is present; compatibility libraries are allowed'
fi
grep -Fq '/usr/bin/os-prober' <<<"$manifest" || fail 'os-prober is missing from the ISO payload'
grep -Fq '/usr/bin/ntfs-3g' <<<"$manifest" || fail 'ntfs-3g is missing from the ISO payload'

mango_user_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/rootfs.img" etc/skel/.config/mango/config.conf)
grep -Fq 'tag_num=2' <<<"$mango_user_config" || fail 'Mango user workspace default is not two'
grep -Fq 'source_optional=~/.config/mango/noctalia.conf' <<<"$mango_user_config" || fail 'Mango Noctalia color path is missing'

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
grep -Fq '/usr/bin/dinitui' <<<"$manifest" || fail 'DinitUI executable is missing'
grep -Fq '/usr/bin/dinxpanel' <<<"$manifest" || fail 'DINXPanel executable is missing'
grep -Fq '/usr/share/icons/hicolor/scalable/apps/org.dinx.DinitUI.svg' <<<"$manifest" || fail 'DinitUI icon is missing'
grep -Fq '/usr/share/icons/hicolor/scalable/apps/org.dinx.DinxPanel.svg' <<<"$manifest" || fail 'DINXPanel icon is missing'
grep -Fq '/usr/bin/clangd' <<<"$manifest" || fail 'clangd runtime is missing'
grep -Fq '/usr/share/nocted/styles/nocted-light.xml' <<<"$manifest" || fail 'NoctEd light scheme is missing'

grep -Fq '/usr/lib/libscenefx' <<<"$manifest" || fail 'missing Scenefx library'

livefs_required_paths=(
  etc/artools/live.conf
  etc/dinit.d/boot.d/NetworkManager
  etc/dinit.d/boot.d/artix-live
  etc/dinit.d/boot.d/cyan-skillfish-governor-smu
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

printf 'ISO content check passed: MangoWM with two editable desktops and floating defaults, top Noctalia bar, bottom Noctalia dock, Noctty terminal contract, Firefox default with pro-user policy, BC250 Control Center pinned to the dock with a user-session daemon, AMDGPU firmware/RADV/Vulkan diagnostics and Cyan Skillfish governor, btop/nvtop/inxi diagnostics, Zathura PDF and Swayimg image handlers, VLC video playback, Strawberry music playback, pwvucontrol audio mixer, topgrade/paru/Shelly package management, UFW/Gufw and OpenSnitch firewall tools, Qps process manager, NetworkManager/nm-connection-editor, BlueZ/Blueman/UPower, CLI recovery and transfer tools, Thunar/GVFS removable-media support, File Roller, Nano and Tumbler.\n'
