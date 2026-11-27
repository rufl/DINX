#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
pkgdir="$root/distro/packages/redbean"
pkgbuild="$pkgdir/PKGBUILD"
build_zig="$pkgdir/build.zig"
header="$pkgdir/src/gtk.h"
frontend="$pkgdir/src/main.zig"
readme="$pkgdir/README.md"
uninstall_helper="$pkgdir/redbean-uninstall"
design_doc="$root/docs/redbean.md"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
greetd_config="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml"
river_session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-session"
river_init="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-init"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
redbean_wrapper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-redbean-session"
redbean_session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/wayland-sessions/dinx-river-kwm-redbean.desktop"
container_builder="$root/scripts/build-iso-container.sh"
docker_builder="$root/scripts/build-iso-docker.sh"
smoke_script="$root/scripts/smoke_redbean.sh"

fail() {
  printf 'redbean_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$build_zig" "$header" "$frontend" "$readme" "$uninstall_helper" \
  "$design_doc" "$profile" "$groups" "$greetd_config" "$river_session" "$river_init" "$supervisor" \
  "$redbean_wrapper" "$redbean_session" "$container_builder" "$docker_builder" "$smoke_script"; do
  [[ -r "$path" ]] || fail "missing input: ${path#$root/}"
done

# Redbean is the secondary selectable NEXT session; Morghulis remains default.
grep -Fqx 'pkgname=redbean' "$pkgbuild" || fail 'package identity is not redbean'
grep -Eq '^[[:space:]]*source=\(\)[[:space:]]*$' "$pkgbuild" || fail 'redbean must build from checked-in sources'
grep -Fq 'zig>=0.17' "$pkgbuild" || fail 'redbean does not pin the Zig 0.17 build toolchain'
grep -Fq "depends=('astal'" "$pkgbuild" || fail 'redbean does not depend on Astal'
grep -Fq 'gtk4-layer-shell' "$pkgbuild" || fail 'redbean does not depend on gtk4-layer-shell'
grep -Fq 'install -Dm755 redbean-uninstall "$pkgdir/usr/lib/redbean/uninstall"' "$pkgbuild" \
  || fail 'redbean uninstall helper is not installed'
grep -Fq 'install -Dm755 "$srcdir/stage/bin/redbean" "$pkgdir/usr/bin/redbean"' "$pkgbuild" \
  || fail 'redbean is not installed to /usr/bin/redbean'
grep -Fq 'linkSystemLibrary("astal-apps"' "$build_zig" || fail 'build does not link Astal Apps'
grep -Fq 'linkSystemLibrary("astal-river"' "$build_zig" || fail 'build does not link Astal River'
grep -Fq 'linkSystemLibrary("astal-wireplumber"' "$build_zig" || fail 'build does not link Astal WirePlumber'
grep -Fq 'linkSystemLibrary("astal-notifd"' "$build_zig" || fail 'build does not link Astal Notifd'
grep -Fq 'linkSystemLibrary("astal-tray"' "$build_zig" || fail 'build does not link Astal Tray'
grep -Fq 'linkSystemLibrary("gtk4-layer-shell"' "$build_zig" || fail 'build does not link GTK4 layer shell'

grep -Fq 'build_package redbean' "$container_builder" \
  || fail 'container builder does not compile Redbean'
grep -Fq 'pacman_install_local "$package_repo"/redbean-*.pkg.tar.zst' "$container_builder" \
  || fail 'container builder does not install Redbean'
if grep -Fq 'DINX_BUILD_REDBEAN' "$docker_builder" "$container_builder"; then
  fail 'Redbean must be unconditional in the NEXT ISO builder'
fi

# UI, integration and launch contracts.
grep -Fq 'astal_apps_apps_fuzzy_query' "$header" || fail 'Astal fuzzy application search is missing'
grep -Fq 'astal_apps_application_get_categories(application, &category_count)' "$header" \
  || fail 'Redbean does not pass the Astal categories array length'
grep -Fq 'g_strfreev(categories)' "$header" \
  || fail 'Redbean does not release the Astal categories array'
grep -Fq 'redbean_file_search' "$header" || fail 'file search is missing'
grep -Fq 'settings_items' "$frontend" || fail 'settings search catalog is missing'
grep -Fq 'gtk_layer_set_anchor' "$frontend" || fail 'redbean does not use layer-shell anchoring'
grep -Fq 'GTK_LAYER_SHELL_LAYER_OVERLAY' "$frontend" || fail 'redbean menu is not an overlay surface'
grep -Fq 'GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND' "$frontend" || fail 'redbean menu has no on-demand keyboard mode'
grep -Fq 'windows' "$frontend" || fail 'Windows mode is missing'
grep -Fq 'flow' "$frontend" || fail 'Flow mode is missing'
grep -Fq 'redbean.json' "$frontend" || fail 'mode persistence path is missing'
grep -Fq 'pinned' "$frontend" || fail 'editable pins are missing'
grep -Fq 'redbean_spawn_fixed_args("/usr/bin/pkill", "-HUP", "dinx-dock"' "$frontend" || fail 'Redbean does not signal dinx-dock'
grep -Fq 'redbean_river_command' "$header" || fail 'window switching is missing'
grep -Fq 'redbean_river_move_tag' "$header" || fail 'workspace controls are missing'
grep -Fq 'redbean_audio_change' "$header" || fail 'audio controls are missing'
grep -Fq 'redbean_notifications_each' "$header" || fail 'notification tray is missing'
grep -Fq 'redbean_spawn_fixed_args("/usr/lib/redbean/uninstall"' "$frontend" || fail 'application uninstall action is missing'
grep -Fq '[ ! -e "$config_home/kwm/config.zon" ]' "$river_session" \
  || fail 'KWM config seed does not preserve existing user configuration'
grep -Fq 'install -Dm644 /etc/xdg/kwm/config.zon "$config_home/kwm/config.zon"' "$river_session" \
  || fail 'KWM config seed is not installed from the packaged XDG default'
grep -Fq 'export DINX_SHELL=redbean' "$redbean_wrapper" || fail 'Redbean wrapper does not select the shell'
grep -Fqx 'exec /usr/local/libexec/dinx-session-supervisor river' "$river_init" \
  || fail 'River init does not delegate session startup to the supervisor'
grep -Fqx 'shell=${DINX_SHELL:-morghulis}' "$supervisor" \
  || fail 'session supervisor lost the Morghulis default shell selector'
grep -Fq 'morghulis|redbean) ;;' "$supervisor" \
  || fail 'session supervisor does not support both selectable shells'
grep -Fqx 'start_required shell "$shell"' "$supervisor" \
  || fail 'session supervisor does not start and monitor the selected shell'

grep -Fq '@window_bg_color' "$frontend" || fail 'redbean does not use semantic GTK theme colors'
grep -Fq 'g_desktop_app_info_new' "$header" || fail 'desktop-entry launch path is missing'
grep -Fq 'redbean_spawn_fixed' "$header" || fail 'fixed session action launcher is missing'
if grep -Eq 'system\(|popen|/bin/sh|execv\(|execvp\(' "$frontend" "$header"; then
  fail 'redbean contains arbitrary shell execution'
fi
# The package helper is a fixed, validated package-management boundary.
grep -Fq 'pacman -Qo' "$uninstall_helper" || fail 'uninstall helper does not resolve package ownership'
grep -Fq 'pkexec pacman -Rns' "$uninstall_helper" || fail 'uninstall helper has no authenticated removal'
if grep -Eq 'eval |sh -c|bash -c' "$uninstall_helper"; then
  fail 'uninstall helper evaluates shell input'
fi


grep -Fq 'WAYLAND_DISPLAY' "$smoke_script" || fail 'runtime smoke does not require a Wayland display'
grep -Fq 'redbean_runtime_smoke started=true' "$smoke_script" || fail 'runtime smoke has no startup result'

grep -Fqx '    - redbean' "$profile" || fail 'redbean is missing from the NEXT profile'
grep -Fq '        "redbean",' "$groups" || fail 'redbean is missing from the desktop feature group'
grep -Fq 'greetd-tuigreet' "$profile" || fail 'tuigreet is missing from the NEXT profile'
grep -Fq 'tuigreet --sessions /usr/share/wayland-sessions' "$greetd_config" \
  || fail 'greetd does not expose Wayland session selection'
grep -Fq 'Name=River + KWM + Redbean (DINX)' "$redbean_session" \
  || fail 'Redbean session is not visible in the greeter'
grep -Fqx 'Exec=/usr/local/libexec/dinx-redbean-session' "$redbean_session" \
  || fail 'Redbean session wrapper is incorrect'
grep -Fq 'DINX_BUILD_REDBEAN' "$docker_builder" && fail 'Redbean must no longer be opt-in in the ISO builder'
grep -Fq 'if [[ "$redbean_build" == true ]]' "$container_builder" && fail 'Redbean build remains conditional'
grep -Fq 'NEXT' "$design_doc" || fail 'Redbean session boundary is not documented'

printf 'redbean_contract package=in_tree session=secondary greeter=tuigreet river=true kwm=true morghulis_default=true modes=windows+flow semantic_theme=true fixed_launch=true\n'
