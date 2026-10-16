#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
noctalia_config="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/config.toml"
palette="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/noctalia/palettes/DINX.json"
profile_shell="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
greeter="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/regreet.toml"
greeter_launcher="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-regreet"
grub="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/grub/themes/artix/theme.txt"
calamares="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/stylesheet.qss"
qt="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/qt6ct.conf"
swayimg="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/swayimg/init.lua"
mango="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/mango/config.conf"
gtk_index="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/index.theme"
gtk3="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-3.0/gtk.css"
gtk3_dark="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-3.0/gtk-dark.css"
gtk4="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-4.0/gtk.css"
gtk4_dark="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-4.0/gtk-dark.css"
fail() {
  printf 'check_dinx_theme: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$noctalia_config" "$palette" "$profile_shell" "$greeter" \
  "$greeter_launcher" "$grub" "$calamares" "$qt" "$swayimg" "$mango" "$gtk_index" \
  "$gtk3" "$gtk3_dark" "$gtk4" "$gtk4_dark"; do
  [[ -r "$path" ]] || fail "missing file: $path"
done

python - "$palette" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    palette = json.load(stream)

roles = {
    "mPrimary", "mOnPrimary", "mSecondary", "mOnSecondary", "mTertiary",
    "mOnTertiary", "mError", "mOnError", "mSurface", "mOnSurface",
    "mSurfaceVariant", "mOnSurfaceVariant", "mOutline", "mShadow",
    "mHover", "mOnHover",
}
terminal_roles = {"background", "foreground", "cursor", "cursorText", "selectionBg", "selectionFg"}
ansi_roles = {"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}
for mode in ("dark", "light"):
    values = palette.get(mode)
    if not isinstance(values, dict):
        raise SystemExit(f"{mode} palette is missing")
    if not roles <= values.keys():
        raise SystemExit(f"{mode} palette is missing semantic roles")
    terminal = values.get("terminal")
    if not isinstance(terminal, dict) or not terminal_roles <= terminal.keys():
        raise SystemExit(f"{mode} palette is missing terminal roles")
    if not isinstance(terminal.get("normal"), dict) or not ansi_roles <= terminal["normal"].keys():
        raise SystemExit(f"{mode} palette is missing normal ANSI colors")
    if not isinstance(terminal.get("bright"), dict) or not ansi_roles <= terminal["bright"].keys():
        raise SystemExit(f"{mode} palette is missing bright ANSI colors")
PY

grep -Fqx '    - qt6ct' "$profile" || fail 'profile does not install qt6ct'
grep -Fqx '    - adw-gtk-theme' "$profile" || fail 'profile does not install adw-gtk-theme'
grep -Fqx '    - cantarell-fonts' "$profile" || fail 'profile does not install Cantarell fonts'
grep -Fq 'source = "custom"' "$noctalia_config" || fail 'Noctalia custom palette source is missing'
grep -Fq 'custom_palette = "DINX"' "$noctalia_config" || fail 'Noctalia DINX palette selection is missing'
grep -Fq 'builtin_ids = ["btop", "foot", "ghostty", "gtk3", "gtk4", "kcolorscheme", "mango", "qt"]' "$noctalia_config" || fail 'Noctalia application template set is incomplete'
grep -Fq 'font_family = "Cantarell"' "$noctalia_config" || fail 'Noctalia font contract is missing'
grep -Fq 'source_optional=~/.config/mango/noctalia.conf' "$mango" || fail 'Mango does not consume the Noctalia template output'
grep -Fq 'theme_name = "DINX"' "$greeter" || fail 'ReGreet does not use DINX theme'
grep -Fq 'GTK_THEME="${GTK_THEME:-DINX:dark}"' "$greeter_launcher" || fail 'ReGreet launcher does not force DINX fallback theme'
grep -Fq 'QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"' "$profile_shell" || fail 'Qt6ct session adapter is missing'
grep -Fq 'NOCTALIA_COLOR_SCHEME="${NOCTALIA_COLOR_SCHEME:-dark}"' "$profile_shell" || fail 'Noctalia color scheme environment contract is missing'
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/noctalia.conf' "$qt" || fail 'Qt6ct does not consume Noctalia colors'
grep -Fq 'desktop-color: "#0b0d12"' "$grub" || fail 'GRUB surface does not use DINX background'
grep -Fq 'selected_item_color = "#8fb8ff"' "$grub" || fail 'GRUB selection does not use DINX primary color'
if grep -Eq '^[[:space:]]*(desktop-image|menu_pixmap_style|selected_item_pixmap_style)[[:space:]]*=' "$grub"; then
  fail 'GRUB still uses an opaque/image-backed DINX-incompatible surface'
fi
for gtk_theme in "$gtk3" "$gtk4"; do
  grep -Fq 'background-color: #0b0d12' "$gtk_theme" || fail "GTK theme lacks DINX surface: $gtk_theme"
  grep -Fq 'color: #d7dde8' "$gtk_theme" || fail "GTK theme lacks DINX foreground: $gtk_theme"
  grep -Fq 'background-color: #8fb8ff' "$gtk_theme" || fail "GTK theme lacks DINX primary state: $gtk_theme"
done
grep -Fq 'background: #0b0d12' "$calamares" || fail 'Calamares surface does not use DINX background'
grep -Fq 'Name=DINX' "$gtk_index" || fail 'GTK theme index name is missing'
grep -Fqx '@import url("gtk.css");' "$gtk3_dark" || fail 'GTK3 dark theme bridge is missing'
grep -Fqx '@import url("gtk.css");' "$gtk4_dark" || fail 'GTK4 dark theme bridge is missing'
grep -Fq 'swayimg.gallery.window_color = 0xff0b0d12' "$swayimg" || fail 'Swayimg surface color is missing'
grep -Fq 'color: #d7dde8' "$calamares" || fail 'Calamares foreground does not use DINX text'
grep -Fq 'background: #8fb8ff' "$calamares" || fail 'Calamares primary state does not use DINX accent'

printf 'dinx_theme_contract palette=true templates=true typography=true gtk=true qt=true mango=true swayimg=true greeter=true grub=true calamares=true\n'
