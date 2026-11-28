#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkgdir="$root/distro/packages/dinx-dock"
pkgbuild="$pkgdir/PKGBUILD"
control="$pkgdir/dinx-dockctl"
ipc="$pkgdir/src/kwm_ipc.zig"
frontend="$pkgdir/src/main.zig"
desktop="$pkgdir/resources/dinx-dock.desktop"
kwm_pkg="$root/distro/packages/kwm/PKGBUILD"
kwm_patch="$root/distro/packages/kwm/dinx-kwm-dock-ipc.patch"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"

fail() {
  printf 'dinx_dock_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$frontend" "$ipc" "$desktop" "$kwm_pkg" "$kwm_patch" "$supervisor" "$profile"; do
  [[ -r "$path" ]] || fail "missing input: $path"
done

# Package identity: an in-tree Zig app linking the layer-shell protocol.
grep -Fqx 'pkgname=dinx-dock' "$pkgbuild" || fail 'PKGBUILD package name is not dinx-dock'
grep -Eq '^[[:space:]]*source=\(\)[[:space:]]*$' "$pkgbuild" || fail 'dinx-dock must build from its checked-in source tree'
grep -Fq 'gtk4-layer-shell' "$pkgbuild" || fail 'dinx-dock does not link the Wayland layer-shell library'
grep -Fq 'install -Dm755 "$srcdir/stage/bin/dinx-dock" "$pkgdir/usr/bin/dinx-dock"' "$pkgbuild" \
  || fail 'dinx-dock is not installed to /usr/bin/dinx-dock'
grep -Fq 'install -Dm755 dinx-dockctl "$pkgdir/usr/bin/dinx-dockctl"' "$pkgbuild" \
  || fail 'dinx-dockctl is not installed'
[[ -r "$control" ]] || fail 'missing dock control helper'
grep -Fq 'jq' "$control" || fail 'dock control helper does not update JSON'
grep -Fq 'depends=(gtk4 gtk4-layer-shell hicolor-icon-theme jq)' "$pkgbuild" \
  || fail 'runtime dependencies omit jq required by dinx-dockctl'
grep -Fq 'zig test src/kwm_ipc.zig' "$pkgbuild" || fail 'package check does not execute the window IPC parser test'

# The dock reads the shared appearance file and honors every placement,
# including the `none` member, which must exit before any display connection.
grep -Fq 'dinx/appearance.json' "$frontend" || fail 'dinx-dock does not read the shared appearance file'
# The three placed edges are the parsed JSON strings; `none` is the enum member
# that disables the dock instead of drawing it.
for placement in '"left"' '"right"' '"bottom"'; do
  grep -Fq "$placement" "$frontend" || fail "dinx-dock does not handle the dock placement: $placement"
done
grep -Fq '.none' "$frontend" || fail 'dinx-dock has no way to disable the dock'
grep -Fq 'gtk_layer_set_anchor' "$frontend" || fail 'dinx-dock does not anchor to the layer shell'
grep -Fq 'gtk_layer_auto_exclusive_zone_enable' "$frontend" \
  || fail 'dinx-dock does not reserve exclusive screen space'
grep -Fq 'favorites' "$frontend" || fail 'dinx-dock does not expose user-configurable favorites'
grep -Fq 'show_activity' "$frontend" || fail 'dinx-dock does not expose activity indicator settings'
grep -Fq 'dinx-dock-box' "$frontend" || fail 'dinx-dock has no styled surface container'
grep -Fq 'activity' "$frontend" || fail 'dock has no launch activity feedback'
if grep -Eq 'system\(|popen|execv?[lp]?\(|/bin/sh' "$frontend"; then
  fail 'dinx-dock executes an arbitrary shell command instead of a fixed desktop entry'
fi
# User-visible dock behavior: configurable favorites, safe per-user settings and activity feedback.
grep -Fq 'favorites:' "$frontend" || fail 'dock does not read configurable favorites'
grep -Fq 'slot.activity' "$frontend" || fail 'dock does not record launch activity'
grep -Fq 'gtk_image_set_pixel_size' "$frontend" || fail 'dock does not honor configured icon size'
grep -Fq 'transform: scale(1.14)' "$frontend" || fail 'dock does not magnify buttons on hover'
grep -Fq 'KwmIpc.query' "$frontend" || fail 'dock does not query KWM window state'
grep -Fq 'KwmIpc.focus' "$frontend" || fail 'dock does not focus existing windows'
grep -Fq 'KwmIpc.closeWindow' "$frontend" || fail 'dock does not gracefully request close'
grep -Fq 'g_timeout_add_seconds(1, &onKwmPoll' "$frontend" || fail 'dock does not refresh window state'
grep -Fq 'DINXKW/1' "$ipc" || fail 'dock IPC protocol version is missing'
grep -Fq 'dinx-kwm-dock-ipc.patch' "$kwm_pkg" || fail 'KWM package does not apply its Dock IPC patch'
grep -Fq 'DinxIpc.start' "$kwm_patch" || fail 'KWM IPC server is not started'
grep -Fq 'ctx.focus(window, true)' "$kwm_patch" || fail 'KWM IPC does not focus windows'
grep -Fq 'window.prepare_close()' "$kwm_patch" || fail 'KWM IPC does not request graceful close'
grep -Fq 'probe_result == 0) return error.SocketBindFailed' "$kwm_patch" || fail 'KWM must preserve an active Dock IPC socket'
grep -Fq 'probe_errno == .CONNREFUSED and unlink(path)' "$kwm_patch" || fail 'KWM does not recover a stale Dock IPC socket safely'
if grep -Eq 'checkRunningApps|pgrep|std\.process\.spawn|kill\(' "$frontend" "$ipc"; then
  fail 'dock scans or signals processes instead of using KWM window management'
fi
if grep -Fq 'parseFromSliceLeaky' "$frontend"; then
  fail 'dinx-dock must not leak parsed config on reload'
fi
grep -Fq 'std.json.parseFromSlice(' "$frontend" || fail 'dinx-dock config reload must use deinit-able JSON parsing'
# Session wiring: the supervisor starts the dock as an optional helper so a
# missing dock can never blank the desktop, and the roster ships it.
grep -Fq 'start_optional dock dinx-dock' "$supervisor" || fail 'the supervisor does not start dinx-dock'
grep -Fq '    - dinx-dock' "$profile" || fail 'the DINX profile does not install dinx-dock'

printf 'dinx_dock_contract package=in-tree layer_shell=true exclusive_zone=true placement=left+right+bottom+none configurable_favorites=true window_list=true focus=true graceful_close=true launch_feedback=true hover_zoom=true no_process_polling=true no_shell_exec=true supervisor=optional roster=true systemd=false\n'