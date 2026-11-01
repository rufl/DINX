#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-qt6ct-palette-seed"
seed="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/missing/qt6ct/colors" "$tmp/legacy/qt6ct/colors" "$tmp/custom/qt6ct/colors" "$tmp/symlink/qt6ct/colors"

missing="$tmp/missing/qt6ct/colors/DINX.conf"
"$helper" "$missing" "$seed"
cmp -s "$seed" "$missing"

legacy="$tmp/legacy/qt6ct/colors/DINX.conf"
cat >"$legacy" <<'LEGACY'
[ColorScheme]
active_colors=#ff0b0d12, #ffd7dde8, #ff0b0d12, #ff11151d, #ff11151d, #ffd7dde8, #ffd7dde8, #ff11151d, #ffd7dde8, #fff7768e, #ff8fb8ff, #ff0b0d12, #ff7dcfff, #ffbb9af7, #ff263249, #ff263249, #ff7f8a9c, #ff05070b, #ff05070b, #ff7f8a9c, #ff8fb8ff
disabled_colors=#ff11151d, #ff7f8a9c, #ff11151d, #ff11151d, #ff11151d, #ff7f8a9c, #ff7f8a9c, #ff11151d, #ff7f8a9c, #ff7f8a9c, #ff263249, #ff7f8a9c, #ff7f8a9c, #ff7f8a9c, #ff263249, #ff263249, #ff7f8a9c, #ff05070b, #ff05070b, #ff7f8a9c, #ff263249
inactive_colors=#ff0b0d12, #ffd7dde8, #ff0b0d12, #ff11151d, #ff11151d, #ffd7dde8, #ffd7dde8, #ff11151d, #ffd7dde8, #fff7768e, #ff8fb8ff, #ff0b0d12, #ff7dcfff, #ffbb9af7, #ff263249, #ff263249, #ff7f8a9c, #ff05070b, #ff05070b, #ff7f8a9c, #ff8fb8ff
LEGACY
custom="$tmp/custom/qt6ct/colors/DINX.conf"
cp "$legacy" "$custom"
printf '# user customization\n' >>"$custom"
before=$(sha256sum "$custom" | cut -d ' ' -f 1)
"$helper" "$custom" "$seed"
after=$(sha256sum "$custom" | cut -d ' ' -f 1)
test "$before" = "$after"

"$helper" "$legacy" "$seed"
cmp -s "$seed" "$legacy"

symlink_target="$tmp/legacy-palette.conf"
cp "$legacy" "$symlink_target"
symlink="$tmp/symlink/qt6ct/colors/DINX.conf"
ln -s "$symlink_target" "$symlink"
"$helper" "$symlink" "$seed"
test -L "$symlink"
cmp -s "$symlink_target" "$legacy"

printf 'dinx_qt_palette_smoke missing_seed=true stock_upgrade=true customized_preserved=true symlink_preserved=true\n'
