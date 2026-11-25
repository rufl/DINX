#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pkgdir="$root/distro/packages/dinx-dock"
pkgbuild="$pkgdir/PKGBUILD"
frontend="$pkgdir/src/main.zig"
desktop="$pkgdir/resources/dinx-dock.desktop"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"

fail() {
  printf 'dinx_dock_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$pkgbuild" "$frontend" "$desktop" "$supervisor" "$profile"; do
  [[ -r "$path" ]] || fail "missing input: $path"
done

# Package identity: an in-tree Zig app linking the layer-shell protocol.
grep -Fqx 'pkgname=dinx-dock' "$pkgbuild" || fail 'PKGBUILD package name is not dinx-dock'
grep -Eq '^[[:space:]]*source=\(\)[[:space:]]*$' "$pkgbuild" || fail 'dinx-dock must build from its checked-in source tree'
grep -Fq 'gtk4-layer-shell' "$pkgbuild" || fail 'dinx-dock does not link the Wayland layer-shell library'
grep -Fq 'install -Dm755 "$srcdir/stage/bin/dinx-dock" "$pkgdir/usr/bin/dinx-dock"' "$pkgbuild" \
  || fail 'dinx-dock is not installed to /usr/bin/dinx-dock'
grep -Fqx 'Exec=dinx-dock' "$desktop" || fail 'dinx-dock desktop entry launch command is incorrect'
grep -Fqx 'NoDisplay=true' "$desktop" || fail 'dinx-dock must not appear in the application menu'

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
grep -Fq 'g_desktop_app_info_new' "$frontend" || fail 'dinx-dock does not launch fixed desktop entries'
if grep -Eq 'system\(|popen|execv?[lp]?\(|/bin/sh' "$frontend"; then
  fail 'dinx-dock executes an arbitrary shell command instead of a fixed desktop entry'
fi

# Session wiring: the supervisor starts the dock as an optional helper so a
# missing dock can never blank the desktop, and the roster ships it.
grep -Fq 'start_optional dock dinx-dock' "$supervisor" || fail 'the supervisor does not start dinx-dock'
grep -Fq '    - dinx-dock' "$profile" || fail 'the DINX profile does not install dinx-dock'

printf 'dinx_dock_contract package=in-tree layer_shell=true exclusive_zone=true placement=left+right+bottom+none fixed_launcher=true no_shell_exec=true supervisor=optional roster=true systemd=false\n'
