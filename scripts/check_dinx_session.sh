#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
overlay="$root/distro/iso/iso-profiles/dinx/root-overlay"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
greetd_config="$overlay/etc/greetd/config.toml"
kwm_config="$overlay/etc/xdg/kwm/config.zon"
tmpfiles="$overlay/etc/tmpfiles.d/dinx-dinit.conf"
river_session="$overlay/usr/local/libexec/dinx-river-session"
river_init="$overlay/usr/local/libexec/dinx-river-init"
supervisor="$overlay/usr/local/libexec/dinx-session-supervisor"
logout="$overlay/usr/local/libexec/dinx-logout"
desktop_approval="$overlay/usr/local/libexec/dinx-approve-desktop-launcher"
palette_seed="$overlay/usr/local/libexec/dinx-qt6ct-palette-seed"
desktop_installer="$overlay/etc/skel/Desktop/Install DINX.desktop"
graphics_helper="$overlay/usr/local/libexec/dinx-graphics-profile"
graphics_environment="$overlay/usr/local/libexec/dinx-graphics-environment.sh"
theme_sync="$overlay/usr/local/libexec/dinx-sync-session-theme"
theme_set="$overlay/usr/local/libexec/dinx-set-theme"
installer="$overlay/usr/local/libexec/dinx-installer"
session_dir="$overlay/usr/share/wayland-sessions"
river_entry="$session_dir/dinx-river-kwm-morghulis.desktop"
gaming_session="$session_dir/dinx-gaming.desktop"
lock="$overlay/usr/local/libexec/dinx-lock"
idle="$overlay/usr/local/libexec/dinx-idle"
desktop="$overlay/usr/share/applications/dinx-lock.desktop"
desktop_surface="$overlay/usr/local/libexec/dinx-pcmanfm-desktop"
live_package="$root/distro/packages/dinx-live-autologin"
kwm_pkgbuild="$root/distro/packages/kwm/PKGBUILD"
kwim_pkgbuild="$root/distro/packages/kwim/PKGBUILD"
morghulis_pkgbuild="$root/distro/packages/morghulis/PKGBUILD"
morghulis_actions="$root/distro/packages/morghulis/morghulis-dinx-actions.patch"
morghulis_river_tags="$root/distro/packages/morghulis/morghulis-dinx-river-tags.patch"
kwm_env="$root/distro/packages/kwm/source.env"
kwim_env="$root/distro/packages/kwim/source.env"
builder="$root/scripts/build-iso-container.sh"
architecture="$root/docs/architecture.md"
compatibility="$root/docs/compatibility.md"
pt_architecture="$root/docs/pt-BR/architecture.md"
pt_compatibility="$root/docs/pt-BR/compatibility.md"
shell_profile="$overlay/etc/profile.d/dinx.sh"
fish_config="$overlay/etc/fish/config.fish"
useradd_defaults="$overlay/etc/default/useradd"
users_conf="$overlay/etc/calamares/modules/users.conf"
gtk3_system="$overlay/etc/xdg/gtk-3.0/settings.ini"
gtk3_skel="$overlay/etc/skel/.config/gtk-3.0/settings.ini"
gtk4_system="$overlay/etc/xdg/gtk-4.0/settings.ini"
gtk4_skel="$overlay/etc/skel/.config/gtk-4.0/settings.ini"
qemu_session_checker="$root/scripts/check_dinx_qemu_session.sh"
iso_smoke="$root/scripts/smoke-iso.sh"
install_smoke="$root/scripts/smoke-install.sh"
logout="$overlay/usr/local/libexec/dinx-logout"

fail() {
  printf 'check_dinx_session: %s\n' "$*" >&2
  exit 1
}

for path in \
  "$profile" "$greetd_config" "$tmpfiles" "$kwm_config" \
  "$river_session" "$river_init" "$supervisor" "$logout" \
  "$desktop_approval" "$palette_seed" "$desktop_installer" "$theme_sync" "$theme_set" "$installer" \
  "$river_entry" "$gaming_session" "$lock" "$idle" "$desktop" "$desktop_surface" \
  "$shell_profile" "$fish_config" "$useradd_defaults" "$users_conf" \
  "$graphics_helper" "$graphics_environment" \
  "$kwm_pkgbuild" "$root/distro/packages/kwm/source.env" \
  "$kwim_pkgbuild" "$root/distro/packages/kwim/source.env" \
  "$morghulis_pkgbuild" "$morghulis_actions" \
  "$morghulis_river_tags" \
  "$gtk3_system" "$gtk3_skel" "$gtk4_system" "$gtk4_skel" \
  "$qemu_session_checker" "$iso_smoke" "$install_smoke"; do
  [[ -r "$path" ]] || fail "missing $path"
done

# The installed session set is closed: only the River/KWM entry and the hidden
# gaming launcher may be selectable by the greeter.
for session_path in "$session_dir"/*.desktop; do
  [[ -e "$session_path" ]] || continue
  case "${session_path##*/}" in
    dinx-river-kwm-morghulis.desktop|dinx-gaming.desktop) ;;
    *) fail "unsupported user session entry remains: ${session_path#$root/}" ;;
  esac
done

# The shipped session/libexec surface is closed: retired compositors, greeters
# and config tuners must not come back, and nothing else may masquerade as a
# DINX session component.
for retired in \
  "$overlay/etc/greetd/regreet.toml" \
  "$overlay/usr/local/libexec/dinx-regreet" \
  "$root/distro/packages/matugen/PKGBUILD"; do
  [[ ! -e "$retired" ]] || fail "retired session path remains: ${retired#$root/}"
done
# The retired compositor/shell recipes and their roster entries are matched by
# name prefix so no retired product name reappears in this gate.
while IFS= read -r retired_recipe; do
  fail "retired session package recipe remains: ${retired_recipe#$root/}"
done < <(find "$root/distro/packages" -maxdepth 2 -type f -name PKGBUILD \( -path '*/aq*/PKGBUILD' -o -path '*/pea*/PKGBUILD' \))
if grep -Eq '^    - [a-z0-9._-]*(aq|pea)[a-z0-9._-]*$' "$profile"; then
  fail 'a retired compositor or shell package remains in the profile'
fi
while IFS= read -r helper_path; do
  case "${helper_path##*/}" in
    dinx-river-session|dinx-river-init|dinx-session-supervisor|dinx-logout|dinx-pcmanfm-desktop|dinx-desktop-first-run|dinx-approve-desktop-launcher|dinx-qt6ct-palette-seed|dinx-sync-session-theme|dinx-set-theme|dinx-graphics-profile|dinx-graphics-environment.sh|dinx-idle|dinx-lock|dinx-installer|dinx-gaming|dinx-bluetooth-manager|dinx-gparted) ;;
  esac
done < <(find "$overlay/usr/local/libexec" -maxdepth 1 -type f)

# Every session/launcher command must resolve inside the overlay: a dangling
# Exec is how a removed compositor kept appearing in the greeter catalogue.
while IFS= read -r desktop_file; do
  while IFS= read -r key; do
    command_path=${key#*=}
    command_path=${command_path#dbus-run-session }
    command_path=${command_path%% *}
    case "$command_path" in
      /usr/*|/etc/*) [[ -e "$overlay$command_path" ]] \
        || fail "dangling session command in ${desktop_file#$root/}: $command_path" ;;
    esac
  done < <(grep -E '^(Exec|TryExec)=/' "$desktop_file" || true)
done < <(find "$session_dir" "$overlay/usr/share/applications" -name '*.desktop' -type f)

[[ -x "$river_session" ]] || fail 'River session wrapper is not executable'
sh -n "$river_session" || fail 'River session wrapper has invalid shell syntax'
[[ -x "$river_init" ]] || fail 'River session init is not executable'
sh -n "$river_init" || fail 'River session init has invalid shell syntax'
[[ -x "$supervisor" ]] || fail 'session supervisor is not executable'
sh -n "$supervisor" || fail 'session supervisor has invalid shell syntax'
[[ -x "$logout" ]] || fail 'logout helper is not executable'
sh -n "$logout" || fail 'logout helper has invalid shell syntax'
[[ -x "$desktop_surface" ]] || fail 'PCManFM desktop wrapper is not executable'
sh -n "$desktop_surface" || fail 'PCManFM desktop wrapper has invalid shell syntax'
grep -Fq 'show_desktop=1' "$desktop_surface" || fail 'PCManFM profile does not force desktop icons'
grep -Fq 'show_wm_menu=0' "$desktop_surface" || fail 'PCManFM profile does not enable the PCManFM desktop context menu'
grep -Fq 'start_required desktop "$libexec_dir/dinx-pcmanfm-desktop"' "$supervisor" || fail 'PCManFM desktop surface is not required in the main session'
[[ -x "$desktop_installer" ]] || fail 'live installer desktop shortcut is not executable'
python3 -c 'import pathlib,sys; compile(pathlib.Path(sys.argv[1]).read_bytes(), sys.argv[1], "exec")' "$desktop_approval" \
  || fail 'desktop approval helper has invalid Python syntax'
[[ -x "$palette_seed" ]] || fail 'Qt6ct palette seed helper is not executable'
sh -n "$palette_seed" || fail 'Qt6ct palette seed helper has invalid shell syntax'
[[ -x "$theme_sync" ]] || fail 'GTK/Qt session theme synchronizer is not executable'
[[ -x "$theme_set" ]] || fail 'DINX theme action helper is not executable'
sh -n "$theme_set" || fail 'DINX theme action helper has invalid shell syntax'
sh -n "$theme_sync" || fail 'GTK/Qt session theme synchronizer has invalid shell syntax'
[[ -x "$lock" ]] || fail 'lock wrapper is not executable'
[[ -x "$idle" ]] || fail 'idle wrapper is not executable'
sh -n "$idle" || fail 'idle wrapper has invalid shell syntax'
sh -n "$lock" || fail 'lock wrapper has invalid shell syntax'
grep -Fq 'exec /usr/local/libexec/dinx-sync-session-theme' "$theme_set" \
  || fail 'DINX theme action does not synchronize all toolkits'
grep -Fq 'jq --arg variant "$variant"' "$theme_set" \
  || fail 'DINX theme action does not persist the selected variant'
[[ -x "$graphics_helper" ]] || fail 'graphics-profile helper is not executable'
grep -Fq '"morghulis-dinx-actions.patch"' "$morghulis_pkgbuild" \
  || fail 'Morghulis package does not include the DINX action patch'
grep -Fq 'patch --fuzz=0 --forward --strip=1 < "$srcdir/morghulis-dinx-actions.patch"' "$morghulis_pkgbuild" \
  || fail 'Morghulis package does not apply the DINX action patch'
grep -Fq '/usr/local/libexec/dinx-set-theme' "$morghulis_actions" \
  || fail 'Morghulis theme action is not wired to the DINX helper'
grep -Fq '/usr/local/libexec/dinx-lock' "$morghulis_actions" \
  || fail 'Morghulis lock actions are not wired to the DINX helper'
grep -Fq '"morghulis-dinx-river-tags.patch"' "$morghulis_pkgbuild" \
  || fail 'Morghulis package does not include the River tag patch'
grep -Fq 'patch --fuzz=0 --forward --strip=1 < "$srcdir/morghulis-dinx-river-tags.patch"' "$morghulis_pkgbuild" \
  || fail 'Morghulis package does not apply the River tag patch'
grep -Fq 'private void select_output()' "$morghulis_river_tags" \
  || fail 'Morghulis River tags do not handle delayed output readiness'
grep -Fq "astal_river_dep = dependency('astal-river-0.1')" "$morghulis_river_tags" \
  || fail 'Morghulis build may silently omit the River tag backend'

# Roster: the River stack and the greetd/agreety greeter are shipped; the
# retired compositors, session launchers and palette generator are not.
for package in \
  river kwm kwim greetd greetd-agreety seatd elogind dinit shikane \
  brightnessctl swayidle swaylock wlopm fish vulkan-swrast dconf \
  gsettings-desktop-schemas xorg-xwayland qt6ct qt6-wayland lxqt-policykit; do
  grep -Fq "    - $package" "$profile" || fail "profile is missing $package"
done
for package in labwc noctalia uwsm greetd-regreet matugen; do
  if grep -Fqx "    - $package" "$profile"; then
    fail "retired session or greeter package remains in the profile: $package"
  fi
done
grep -Fq 'install -Dm644 "$srcdir/out/share/doc/kwm/config.zon" "$pkgdir/etc/xdg/kwm/config.zon"' "$kwm_pkgbuild" \
  || fail 'kwm does not ship the system-wide config seed used by the session wrapper'
if grep -Fq 'pkgdir/usr/share/wayland-sessions' "$kwm_pkgbuild"; then
  fail 'kwm installs a competing upstream session entry'
fi
grep -Fq 'NoExtract = usr/share/wayland-sessions/river.desktop' "$builder" \
  || fail 'builder does not suppress the competing upstream River session entry'
grep -Fq "provides=('river-input-manager')" "$kwim_pkgbuild" \
  || fail 'kwim does not provide the river input manager'
# Owner decision 2026-11-17: kwm and kwim stay on released upstream tags built by
# a dedicated Zig 0.16 toolchain, because their build.zig reads the Build.build_root
# field that Zig 0.17 removed. Re-pin to a real tag once upstream cuts a
# 0.17-compatible release; do not move to untagged master commits in the meantime.
for env in "$kwm_env" "$kwim_env"; do
  name=$(basename "$(dirname "$env")")
  grep -Eq '^[A-Z]+_SOURCE_URL=https://github\.com/kewuaa/[a-z]+/archive/refs/tags/v[0-9]+(\.[0-9]+)*\.tar\.gz$' "$env" \
    || fail "$name is not pinned to a released upstream tag archive"
  grep -Eq '^[A-Z]+_VERSION=[0-9]+(\.[0-9]+)+$' "$env" \
    || fail "$name version pin is not a semantic release version"
  grep -Eq '^[A-Z]+_ZIG_VERSION=0\.16\.[0-9]+$' "$env" \
    || fail "$name must stay on the Zig 0.16 toolchain until upstream supports 0.17"
  grep -Eq '^[A-Z]+_ZIG_SOURCE_SHA256=[0-9a-f]{64}$' "$env" \
    || fail "$name Zig toolchain checksum is not pinned"
done
grep -Fq 'zig016_version=0.16.0' "$builder" \
  || fail 'builder no longer provides the dedicated Zig 0.16 toolchain for KWM/KWIM'
grep -Fq '"$package_name" == kwm || "$package_name" == kwim ]]; then' "$builder" \
  || fail 'builder no longer routes KWM/KWIM to the Zig 0.16 toolchain'
grep -Fq 'exec /usr/bin/openvt -c 7 -s -f -e -- runuser -u dinx' "$live_package/dinx-live-session" \
  || fail 'the live session does not acquire and activate dedicated VT 7'
grep -Fq 'dbus-run-session /usr/local/libexec/dinx-river-session' "$live_package/dinx-live-session" \
  || fail 'the live session does not launch the River session wrapper under a session bus'

# Shell defaults name the River desktop for recovery TTYs and Fish users.
grep -Fq 'export SHELL=/bin/fish' "$shell_profile" || fail 'POSIX shell default is not Fish'
grep -Fq 'XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-river}"' "$shell_profile" \
  || fail 'POSIX desktop default is not river'
grep -Fq 'export DINX_COLOR_SCHEME=dark' "$shell_profile" \
  || fail 'DINX color scheme default is missing'
grep -Fq 'export DINTOR_THEME=prefer-dark' "$shell_profile" \
  || fail 'Dintor dark-theme preference default is missing'
grep -Fq 'set -gx SHELL /bin/fish' "$fish_config" || fail 'Fish system shell default is missing'
grep -Fq 'set -gx XDG_CURRENT_DESKTOP river' "$fish_config" \
  || fail 'Fish desktop default is not river'
grep -Fq 'set -gx DINX_COLOR_SCHEME dark' "$fish_config" \
  || fail 'Fish DINX color scheme default is missing'
grep -Fq 'SHELL=/bin/fish' "$useradd_defaults" || fail 'new-user shell default is not Fish'
grep -Fq 'shell: /bin/fish' "$users_conf" || fail 'Calamares user shell is not Fish'
grep -Fq '    - render' "$users_conf" || fail 'Calamares users are missing render-node access'

# Installed greetd hands the seat to agreety, which launches the River wrapper.
grep -Fq '[general]' "$greetd_config" || fail 'greetd general section is missing'
grep -Fq 'source_profile = false' "$greetd_config" \
  || fail 'greetd must not source the greeter account profile'
grep -Fq 'command = "env XDG_CACHE_HOME=/var/cache/agreety agreety --cmd /usr/local/libexec/dinx-river-session"' "$greetd_config" \
  || fail 'greetd does not launch the River session through agreety'
grep -Fq 'user = "greeter"' "$greetd_config" \
  || fail 'greetd does not use the greetd-provided greeter account'
if grep -Fq '[initial_session]' "$greetd_config"; then
  fail 'installed greetd config must not enable live autologin'
fi
if grep -Eiq 'systemd|systemctl' "$greetd_config"; then
  fail 'greetd config contains a systemd integration'
fi
grep -Fq 'd /var/cache/agreety 0700 greeter greeter -' "$tmpfiles" \
  || fail 'agreety private cache directory is not provisioned by tmpfiles'

# The session wrapper owns desktop identity, seat backend probing, the graphics
# profile, single-instance locking and the live-session shortcuts. The identity
# must be exactly `river`: Morghulis compares XDG_CURRENT_DESKTOP against the
# literal string to enable its tag, mode and view modules, so a composite value
# such as `river:kwm` silently produces a shell bar without workspaces.
grep -Fqx 'export XDG_CURRENT_DESKTOP=river' "$river_session" \
  || fail 'River session desktop identity is not the exact string river'
grep -Fq 'export XDG_SESSION_DESKTOP=river' "$river_session" \
  || fail 'River session name is not exported'
grep -Fq 'export XDG_SESSION_TYPE=wayland' "$river_session" \
  || fail 'River session does not declare the Wayland session type'
grep -Fq 'export DINX_DISPLAY_AUTHORITY=shikane' "$river_session" \
  || fail 'River session does not name its display authority'
grep -Fq 'export DINX_SESSION_COMPOSITOR_PID=$$' "$river_session" \
  || fail 'River session does not publish its compositor pid to the supervisor'
grep -Fq 'grep -qx seat' "$river_session" \
  || fail 'River session does not verify seatd group membership before selecting the seatd backend'
grep -Fq '[ -S /run/seatd.sock ]' "$river_session" \
  || fail 'River session does not require a live seatd socket before selecting seatd'
grep -Fq 'export LIBSEAT_BACKEND=seatd' "$river_session" \
  || fail 'River session does not select the seatd libseat backend'
grep -Fq 'export LIBSEAT_BACKEND=logind' "$river_session" \
  || fail 'River session does not fall back to elogind for libseat'
grep -Fq 'graphics_profile=$(/usr/local/libexec/dinx-graphics-profile)' "$river_session" \
  || fail 'River session wrapper does not select the graphics profile'
grep -Fq '. /usr/local/libexec/dinx-graphics-environment.sh' "$river_session" \
  || fail 'River session wrapper does not load the shared renderer policy'
grep -Fq 'dinx_apply_graphics_environment "$graphics_profile"' "$river_session" \
  || fail 'River session wrapper does not apply the selected renderer policy'
grep -Fq 'export WLR_RENDERER=gles2' "$graphics_environment" \
  || fail 'VM renderer policy does not use GLES2'
grep -Fq 'export WLR_RENDERER=vulkan' "$graphics_environment" \
  || fail 'VirtualBox renderer policy does not use Vulkan'
grep -Fq 'export WLR_RENDERER=pixman' "$graphics_environment" \
  || fail 'CPU renderer policy does not use pixman'
grep -Fq 'unset GSK_RENDERER' "$graphics_environment" \
  || fail 'GTK4 VM renderer selection is not left automatic'
[[ $(grep -Fc 'unset GSK_RENDERER' "$graphics_environment") -eq 3 ]] \
  || fail 'GTK4 renderer selection is not automatic for CPU, virtual GL and Vulkan profiles'
grep -Fq 'XDG_RUNTIME_DIR=/run/dinx-session' "$river_session" \
  || fail 'live River session does not use its private runtime directory'
grep -Fq 'lock_path=$XDG_RUNTIME_DIR/dinx-river-session.lock' "$river_session" \
  || fail 'River session lock is not scoped to the session runtime directory'
grep -Fq 'flock -n 9' "$river_session" \
  || fail 'River session does not reject a duplicate compositor instance'
grep -Fq 'exec river -c /usr/local/libexec/dinx-river-init' "$river_session" \
  || fail 'River session wrapper does not launch river with the DINX configuration'
grep -Fq 'xdg-user-dirs-update' "$river_session" \
  || fail 'River session does not initialize XDG user directories'
grep -Fq 'export QT_QPA_PLATFORMTHEME=qt6ct' "$river_session" \
  || fail 'River session does not force the Qt6ct platform theme'
grep -Fq 'export MOZ_GTK_TITLEBAR_DECORATION=system' "$river_session" \
  || fail 'River session does not force Gecko browsers to use the system/compositor titlebar'
grep -Fq 'export GTK_CSD=1' "$river_session" \
  || fail 'River session disables GTK client-side decorations'
grep -Fq 'export GTK_DECORATION_LAYOUT=:minimize,maximize,close' "$river_session" \
  || fail 'River session does not define themed GTK window buttons'
grep -Fq '.default_window_decoration = .csd' "$kwm_config" \
  || fail 'KWM is not configured to keep client-side decorations visible'
grep -Fq '.default_layout = .float' "$kwm_config" \
  || fail 'KWM default layout is not floating'
grep -Fq '.{ .floating = true, .decoration = .csd }' "$kwm_config" \
  || fail 'KWM does not force every window into the floating stack'
grep -Fq '.auto_swallow = false' "$kwm_config" \
  || fail 'KWM auto-swallow would replace stacking behavior'
grep -Fq '.remember_floating_geometry = true' "$kwm_config" \
  || fail 'KWM does not preserve floating window geometry'
if grep -Fq 'riverctl' "$river_init"; then
  fail 'River 0.5 rejects any riverctl string in its init file, including comments'
fi
grep -Fq 'exec /usr/local/libexec/dinx-session-supervisor river' "$river_init" \
  || fail 'River init does not launch the supervisor in river mode'
if grep -Eq 'WLR_RENDERER_ALLOW_SOFTWARE|VK_DRIVER_FILES=.*lvp' "$river_session"; then
  fail 'River session still forces the failing software Vulkan path'
fi
grep -Fq "export GTK_THEME='DINX:dark'" "$river_session" "$shell_profile" \
  || fail 'DINX session does not force the dark GTK theme'
grep -Fq 'export ADW_COLOR_SCHEME_FORCE_DARK=1' "$river_session" "$shell_profile" \
  || fail 'DINX session does not force dark libadwaita applications'
if grep -Eiq 'systemd|systemctl|uwsm|labwc|noctalia|regreet' "$river_session" "$river_init" "$supervisor"; then
  fail 'River session path contains a retired session or systemd integration'
fi
if grep -Eq '^[^#]*dinx-sync-session-theme' "$river_session"; then
  fail 'toolkit theme synchronization runs before session D-Bus readiness'
fi

# Live-session shortcuts: the installer launcher is seeded and approved only in
# the disposable session, and the lock action is hidden there.
grep -Fq '[ "${DINX_LIVE_SESSION:-}" = "1" ]' "$river_session" \
  || fail 'automatic launcher approval is not restricted to the disposable live session'
grep -Fq '/usr/local/libexec/dinx-approve-desktop-launcher' "$river_session" \
  || fail 'live River session does not run the desktop approval helper'
grep -Fq '"$installer_desktop" "$installer_seed"' "$river_session" \
  || fail 'live River session does not bind launcher approval to the package-owned template'
grep -Fq 'Hidden=true' "$river_session" \
  || fail 'live River session does not hide the screen-lock action'
grep -Fq 'install -Dm644 /etc/xdg/kwm/config.zon "$config_home/kwm/config.zon"' "$river_session" \
  || fail 'River session does not seed the system kwm configuration for a new user'
kwm_seed_block=$(awk '
  /^if / && /kwm\/config\.zon/ { capture = 1 }
  capture { print }
  capture && /^fi$/ { exit }
' "$river_session")
grep -Fq '[ ! -e "$config_home/kwm/config.zon" ]' <<<"$kwm_seed_block" \
  || fail 'River session may overwrite an existing user kwm configuration'
grep -Fq '[ -r /etc/xdg/kwm/config.zon ]' <<<"$kwm_seed_block" \
  || fail 'River session seeds kwm config without a readable system default'
grep -Fq '/usr/local/libexec/dinx-qt6ct-palette-seed' "$river_session" \
  || fail 'River session does not seed the DINX Qt6ct palette'
grep -Fq 'target_bytes != trusted_bytes' "$desktop_approval" \
  || fail 'desktop approval helper does not require exact package-owned launcher bytes'
grep -Fq 'hashlib.sha256(target_bytes).hexdigest()' "$desktop_approval" \
  || fail 'desktop approval helper does not bind approval to the launcher digest'

# The supervisor only understands the river mode and owns the DINX helpers.
grep -Fq '[ "$mode" = river ]' "$supervisor" \
  || fail 'session supervisor does not restrict itself to the river mode'
grep -Fq 'wait_for_wayland' "$supervisor" || fail 'session supervisor does not gate Wayland readiness'
grep -Fq 'wait_for_dbus' "$supervisor" || fail 'session supervisor does not gate D-Bus readiness'
grep -Fq 'start_required wm kwm' "$supervisor" \
  || fail 'session supervisor does not start the required River window manager'
grep -Fq 'start_required shikane shikane' "$supervisor" \
  || fail 'session supervisor does not start the required display daemon'
grep -Fq 'start_required policykit lxqt-policykit-agent' "$supervisor" \
  || fail 'session supervisor does not start the required PolicyKit agent'
grep -Fq 'start_required idle "$libexec_dir/dinx-idle"' "$supervisor" \
  || fail 'session supervisor does not start the required idle helper'
grep -Fq 'start_optional bc250 bc250-control-centerd' "$supervisor" \
  || fail 'session supervisor does not start the optional BC-250 daemon'
grep -Fq 'set_status ready' "$supervisor" || fail 'session supervisor has no ready status boundary'
grep -Fq 'set_status failed' "$supervisor" || fail 'session supervisor has no failure status boundary'
grep -Fq 'stop_parent' "$supervisor" || fail 'session supervisor does not clean up the tracked compositor parent'
grep -Fq 'start_required shell morghulis' "$supervisor" \
  || fail 'session supervisor does not start the Morghulis desktop shell'
if grep -Eq 'start_(required|optional|background)[[:space:]]+[[:alnum:]_-]+[[:space:]]+river([[:space:]]|$)' "$supervisor"; then
  fail 'session supervisor starts a second compositor'
fi

# Session catalogue identity.
grep -Fq 'Name=River + KWM + Morghulis (DINX)' "$river_entry" || fail 'River session display name is incorrect'
grep -Fq 'Exec=dbus-run-session /usr/local/libexec/dinx-river-session' "$river_entry" \
  || fail 'River session command is incorrect'
grep -Fq 'TryExec=/usr/local/libexec/dinx-river-session' "$river_entry" \
  || fail 'River session TryExec is missing'
grep -Fq 'DesktopNames=river;kwm;morghulis' "$river_entry" || fail 'River session desktop names are missing'
if grep -Eiq 'systemd|systemctl|uwsm' "$river_entry"; then
  fail 'River session entry contains a systemd or UWSM integration'
fi
grep -Fq 'Hidden=true' "$gaming_session" || fail 'gaming session is not hidden'
grep -Fq 'NoDisplay=true' "$gaming_session" || fail 'gaming session remains visible'

for gtk_settings in "$gtk3_system" "$gtk3_skel" "$gtk4_system" "$gtk4_skel"; do
  grep -Fq 'gtk-decoration-layout=:minimize,maximize,close' "$gtk_settings" \
    || fail "GTK fallback window controls are incomplete in ${gtk_settings#$root/}"
done

if grep -Eq '/bin/sh -c|systemctl|loginctl suspend' "$lock" "$idle"; then
  fail 'session wrappers contain forbidden shell indirection or systemd suspend calls'
fi
grep -Fq 'Exec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock action is missing'
grep -Fq 'TryExec=/usr/local/libexec/dinx-lock' "$desktop" || fail 'launcher lock TryExec is missing'

# The installer must reject an incomplete session bus before it reaches
# `set -u` preference handling; otherwise the desktop shortcut exits silently.
grep -Fq 'DBUS_SESSION_BUS_ADDRESS is missing' "$installer" \
  || fail 'installer does not validate the session D-Bus address'
# The installer still consumes the live session's saved preferences.
grep -Fq 'LANG="$locale"' "$installer" || fail 'installer does not pass saved locale to Calamares'
grep -Fq 'XKB_DEFAULT_LAYOUT="$keyboard"' "$installer" \
  || fail 'installer does not pass saved keyboard to Calamares'
grep -Fq '/etc/skel/.config/dinx/installer-preferences.json' "$installer" \
  || fail 'installer does not preserve live preferences in the installed skeleton'

# QEMU screen gates stay wired into the live and installed smokes.
grep -Fq '"$script_dir/check_dinx_qemu_session.sh" "$session_screenshot_path" "$session_mode"' "$iso_smoke" \
  || fail 'QEMU live smoke does not check the configured graphical session surface'
grep -Fq '"$script_dir/check_dinx_qemu_session.sh" "$screen_path" greeter' "$install_smoke" \
  || fail 'installed QEMU smoke does not check the agreety greeter screen'

bash -n "$qemu_session_checker" || fail 'QEMU session checker has invalid shell syntax'

# Desktop launcher approval helper: digest binding, idempotence, private state,
# and rejection of modified or symlinked shortcuts.
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
approval_home="$fixture/home"
approval_target="$fixture/Desktop 42/Install DINX.desktop"
approval_state="$approval_home/state/dinx/desktop-launchers.json"
mkdir -p "$(dirname -- "$approval_target")" "$(dirname -- "$approval_state")"
cp -- "$desktop_installer" "$approval_target"
chmod 0644 "$approval_target"
jq -n --arg uri 'file:///custom.desktop' \
  '{version:1,approvals:[{uri:$uri,digest:([range(0;64)] | map(48) | implode)}],unrelated:{keep:true}}' \
  >"$approval_state"
env HOME="$approval_home" XDG_STATE_HOME="$approval_home/state" \
  "$desktop_approval" "$approval_target" "$desktop_installer"
approval_uri=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve(strict=True).as_uri())' "$approval_target")
approval_digest=$(sha256sum "$approval_target" | cut -d ' ' -f1)
jq -e --arg uri "$approval_uri" --arg digest "$approval_digest" \
  '.version == 1 and .unrelated.keep == true and ([.approvals[] | select(.uri == "file:///custom.desktop")] | length == 1) and ([.approvals[] | select(.uri == $uri and .digest == $digest)] | length == 1)' \
  "$approval_state" >/dev/null \
  || fail 'desktop shortcut approval did not preserve existing state or bind exact URI/content'
[[ $(stat -c '%a' "$approval_target") == 755 ]] \
  || fail 'desktop approval helper did not repair the shortcut executable mode'
[[ $(stat -c '%a' "$approval_state") == 600 ]] \
  || fail 'desktop launcher approvals are not written with private permissions'
approval_state_before=$(sha256sum "$approval_state" | cut -d ' ' -f1)
env HOME="$approval_home" XDG_STATE_HOME="$approval_home/state" \
  "$desktop_approval" "$approval_target" "$desktop_installer"
[[ $(sha256sum "$approval_state" | cut -d ' ' -f1) == "$approval_state_before" ]] \
  || fail 'desktop approval helper rewrote unchanged state'
printf '\n# user edit\n' >>"$approval_target"
if env HOME="$approval_home" XDG_STATE_HOME="$approval_home/state" \
  "$desktop_approval" "$approval_target" "$desktop_installer" >"$fixture/modified.log" 2>&1; then
  fail 'desktop approval helper accepted a modified shortcut'
fi
grep -Fq 'leaving it unapproved' "$fixture/modified.log" \
  || fail 'desktop approval helper did not explain why modified content was rejected'
[[ $(sha256sum "$approval_state" | cut -d ' ' -f1) == "$approval_state_before" ]] \
  || fail 'desktop approval helper changed state for a modified shortcut'
symlink_target="$fixture/Install DINX symlink.desktop"
ln -s "$desktop_installer" "$symlink_target"
if env HOME="$approval_home" XDG_STATE_HOME="$approval_home/state" \
  "$desktop_approval" "$symlink_target" "$desktop_installer" >/dev/null 2>&1; then
  fail 'desktop approval helper followed a symlinked shortcut'
fi
[[ $(sha256sum "$approval_state" | cut -d ' ' -f1) == "$approval_state_before" ]] \
  || fail 'desktop approval helper changed state for a symlink launcher'
corrupt_home="$fixture/corrupt-home"
mkdir -p "$corrupt_home/state/dinx"
printf '%s' '{invalid' >"$corrupt_home/state/dinx/desktop-launchers.json"
cp -- "$desktop_installer" "$approval_target"
if env HOME="$corrupt_home" XDG_STATE_HOME="$corrupt_home/state" \
  "$desktop_approval" "$approval_target" "$desktop_installer" >/dev/null 2>&1; then
  fail 'desktop approval helper accepted corrupt state'
fi
[[ $(cat "$corrupt_home/state/dinx/desktop-launchers.json") == '{invalid' ]] \
  || fail 'desktop approval helper overwrote corrupt state'
printf 'desktop_launcher executable=true preapproved=true exact_digest=true idempotent=true modified_rejected=true symlink_rejected=true corrupt_state_preserved=true private_mode=600\n'

# QEMU screen self-tests against a stubbed OCR engine.
mkdir -p "$fixture/bin"
cat >"$fixture/bin/tesseract" <<'SH'
#!/bin/sh
printf '%s\n' "${DINX_TEST_OCR:-}"
SH
chmod +x "$fixture/bin/tesseract"
qemu_screen="$fixture/screen.ppm"
printf 'P6\n2 2\n255\n\377\377\377\377\377\377\377\377\377\377\377\377' >"$qemu_screen"
ocr_env=("PATH=$fixture/bin:$PATH")
env "${ocr_env[@]}" DINX_TEST_OCR='River + KWM (DINX) - Wayland' \
  "$qemu_session_checker" "$qemu_screen" session >/dev/null
env "${ocr_env[@]}" DINX_TEST_OCR='DINX desktop' \
  "$qemu_session_checker" "$qemu_screen" session >/dev/null
env "${ocr_env[@]}" DINX_TEST_OCR=$'DINX Linux dinx-install-smoke tty7\ndinx-install-smoke login:' \
  "$qemu_session_checker" "$qemu_screen" greeter >/dev/null
sparse_greeter_screen="$fixture/sparse-greeter.ppm"
python3 - "$sparse_greeter_screen" <<'PY'
import sys
from pathlib import Path

width, height = 1280, 800
pixels = bytearray(width * height * 3)
for pixel in range(1470):
    offset = pixel * 3
    pixels[offset:offset + 3] = b"\xff\xff\xff"
Path(sys.argv[1]).write_bytes(f"P6\n{width} {height}\n255\n".encode() + pixels)
PY
env "${ocr_env[@]}" DINX_TEST_OCR=$'DINX Linux dinx-install-smoke tty7\ndinx-install-smoke login:' \
  "$qemu_session_checker" "$sparse_greeter_screen" greeter >/dev/null
env "${ocr_env[@]}" DINX_TEST_OCR='Install DINX' \
  "$qemu_session_checker" "$qemu_screen" first-run >/dev/null
env "${ocr_env[@]}" DINX_TEST_OCR=$'Idioma / Language\nSystem language' \
  "$qemu_session_checker" "$qemu_screen" first-run >/dev/null
if env "${ocr_env[@]}" DINX_TEST_OCR=$'agreety\nPassword\nSign in' \
  "$qemu_session_checker" "$qemu_screen" session >/dev/null; then
  fail 'the session screen check accepted a greeter login screen'
fi
if env "${ocr_env[@]}" DINX_TEST_OCR=$'River + KWM (DINX) - Wayland\nPassword\nSign in\nAccessDenied' \
  "$qemu_session_checker" "$qemu_screen" greeter >/dev/null; then
  fail 'the greeter screen check accepted a startup failure'
fi
if env "${ocr_env[@]}" DINX_TEST_OCR='Wayfire - Wayland' \
  "$qemu_session_checker" "$qemu_screen" session >/dev/null; then
  fail 'the session screen check accepted a foreign compositor title'
fi
if env "${ocr_env[@]}" DINX_TEST_OCR='River + KWM (DINX) - Wayland' \
  "$qemu_session_checker" "$qemu_screen" first-run >/dev/null; then
  fail 'the first-run screen check passed without an installer or wizard marker'
fi
if env "${ocr_env[@]}" DINX_TEST_OCR='River + KWM (DINX) - Wayland' \
  "$qemu_session_checker" "$fixture/missing.ppm" session >/dev/null 2>&1; then
  fail 'the session screen check accepted a missing screenshot'
fi
printf 'qemu_screen_smoke river_title=true dinx_marker=true agreety_login=true sparse_text_greeter=true first_run_shortcut=true first_run_wizard=true greeter_startup_error_rejected=true foreign_compositor_rejected=true login_screen_rejected=true missing_screenshot_rejected=true\n'

bash "$root/scripts/smoke_dinx_session.sh"
bash "$root/scripts/smoke_dinx_session_supervisor.sh"

# The River/agreety session boundary must be documented in every language.
for doc in "$architecture" "$compatibility" "$pt_architecture" "$pt_compatibility"; do
  grep -Eiq '(^|[^[:alnum:]])river([^[:alnum:]]|$)|(^|[^[:alnum:]])kwm([^[:alnum:]]|$)' "$doc" \
    || fail "River session boundary is undocumented: ${doc#$root/}"
  grep -Fiq 'agreety' "$doc" || fail "agreety greeter boundary is undocumented: ${doc#$root/}"
  grep -Fq 'dinit' "$doc" || fail "dinit boundary is undocumented: ${doc#$root/}"
done

printf 'dinx_session_contract session=river_kwm_morghulis=true shell=morghulis greeter=agreety=true greeter_account=greeter=true autologin=false x11=false uwsm=false seat_backend_probe=true single_instance_lock=true live_private_runtime=true live_lock=false live_blank=true installed_lock=true idle=true kwm_config_seed=only_when_absent qt6ct_palette_seed=true theme_env=gtk+qt=true gtk_fallback_controls=minimize+maximize+close=true gtk_dark_mode=prefer-dark-preserves-user=true roster=river+kwm+kwim+morghulis+dinx-dock+dinx-first-run+greetd-agreety=true profiled_defaults=river=true tmpfiles=agreety_cache=true supervisor=river required_helpers=kwm+shikane+policykit+idle+morghulis optional_helpers=bc250=true compositor_parent=true direct_dinit=true systemd=false desktop_launcher=executable+preapproved launcher=true qemu_screen_ocr=true\n'
