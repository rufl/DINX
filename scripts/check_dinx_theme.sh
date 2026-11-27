#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
overlay="$repo_root/distro/iso/iso-profiles/dinx/root-overlay"
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
feature_groups="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
palette="$overlay/usr/share/dinx/theme/DINX.json"
profile_shell="$overlay/etc/profile.d/dinx.sh"
grub="$overlay/usr/share/grub/themes/artix/theme.txt"
grub_defaults="$overlay/etc/default/grub.d/10-dinx-branding.cfg"
live_grub="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/themes/artix/theme.txt"
live_grub_defaults="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/etc/default/grub"
live_grub_logo="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/themes/artix/logo.png"
live_grub_cfg="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/cfg/grub.cfg"
live_grub_kernels="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/cfg/kernels.cfg"
live_grub_variable="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/cfg/variable.cfg"
plymouth_script="$repo_root/distro/packages/dinx-plymouth-theme/dinx.script"
calamares="$overlay/etc/calamares/branding/dinx/stylesheet.qss"
calamares_notes="$overlay/etc/calamares/branding/dinx/notesqml.qml"
calamares_branding="$overlay/etc/calamares/branding/dinx/branding.desc"
qt="$overlay/etc/skel/.config/qt6ct/qt6ct.conf"
qt_palette="$overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
qt_palette_seed="$overlay/usr/local/libexec/dinx-qt6ct-palette-seed"
brand_wordmark="$repo_root/design/brand/dinx-linux-logo.svg"
cli_issue="$overlay/etc/issue"
live_cli_issue="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/etc/issue"
brand_ray_source="$repo_root/design/brand/dinx-ray-mark.svg"
fastfetch_logo="$overlay/usr/share/dinx/branding/dinx-ray-mark.txt"
calamares_wordmark="$overlay/etc/calamares/branding/dinx/dinx.svg"
calamares_ray="$overlay/etc/calamares/branding/dinx/dinx-ray-mark.svg"
grub_logo="$overlay/usr/share/grub/themes/artix/logo.png"
boot_mark_source="$repo_root/design/brand/dinx-boot-mark.svg"
dinitui_source="$repo_root/distro/packages/dinitui/src/main.zig"
dinxpanel_source="$repo_root/distro/packages/dinxpanel/src/main.zig"
gtk_index="$overlay/usr/share/themes/DINX/index.theme"
gtk3="$overlay/usr/share/themes/DINX/gtk-3.0/gtk.css"
gtk3_dark="$overlay/usr/share/themes/DINX/gtk-3.0/gtk-dark.css"
gtk4="$overlay/usr/share/themes/DINX/gtk-4.0/gtk.css"
gtk4_dark="$overlay/usr/share/themes/DINX/gtk-4.0/gtk-dark.css"
gtk3_settings="$overlay/etc/skel/.config/gtk-3.0/settings.ini"
gtk4_settings="$overlay/etc/skel/.config/gtk-4.0/settings.ini"
system_gtk3="$overlay/etc/xdg/gtk-3.0/settings.ini"
system_gtk4="$overlay/etc/xdg/gtk-4.0/settings.ini"
dconf_dark="$overlay/etc/dconf/db/local.d/99-dinx-dark"
session_wrapper="$overlay/usr/local/libexec/dinx-river-session"
theme_sync="$overlay/usr/local/libexec/dinx-sync-session-theme"
kwm_config="$overlay/etc/xdg/kwm/config.zon"
gtk_themes_pkgbuild="$repo_root/distro/packages/dinx-gtk-themes/PKGBUILD"
patchy_launcher="$repo_root/distro/packages/patchy/patchy"
patchy_force_darkest="$repo_root/distro/packages/patchy/patchy-force-darkest"
godot_settings="$overlay/etc/skel/.config/godot/editor_settings-4.tres"
swayimg="$overlay/etc/skel/.config/swayimg/init.lua"
haruna_wrapper="$overlay/usr/local/bin/haruna"
fail() {
  printf 'check_dinx_theme: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$feature_groups" "$palette" "$profile_shell" \
  "$grub" "$grub_defaults" "$grub_logo" "$boot_mark_source" "$calamares" "$calamares_notes" "$calamares_branding" "$calamares_wordmark" \
  "$calamares_ray" "$brand_wordmark" "$brand_ray_source" "$fastfetch_logo" "$cli_issue" \
  "$qt" "$qt_palette" "$swayimg" "$dinitui_source" "$dinxpanel_source" \
  "$gtk_index" "$gtk3" "$gtk3_dark" "$gtk4" "$gtk4_dark" \
  "$gtk3_settings" "$gtk4_settings" "$system_gtk3" "$system_gtk4" "$dconf_dark" \
  "$session_wrapper" "$gtk_themes_pkgbuild" "$qt_palette_seed" "$theme_sync" \
  "$patchy_launcher" "$patchy_force_darkest" "$haruna_wrapper" "$plymouth_script" "$godot_settings"; do
  [[ -r "$path" ]] || fail "missing file: $path"
done
for path in "$live_grub" "$live_grub_defaults" "$live_grub_logo" \
  "$live_grub_cfg" "$live_grub_kernels" "$live_grub_variable" "$live_cli_issue"; do
  [[ -r "$path" ]] || fail "missing file: $path"
done
grep -Fq 'DINX Linux' "$cli_issue" || fail 'CLI login banner is not branded as DINX Linux'
if grep -Eiq 'Artix' "$cli_issue"; then
  fail 'CLI login banner still identifies Artix'
fi
grep -Fq 'DINX Linux' "$live_cli_issue" || fail 'live CLI login banner is not branded as DINX Linux'
if grep -Eiq 'Artix' "$live_cli_issue"; then
  fail 'live CLI login banner still identifies Artix'
fi
cmp -s "$cli_issue" "$live_cli_issue" || fail 'live and installed CLI login banners differ'

# --- the removed theme stack must stay gone -----------------------------------
for removed in \
  "$repo_root/distro/packages/dinx-pearl-themes/PKGBUILD" \
  "$repo_root/distro/packages/pearl/PKGBUILD" \
  "$repo_root/distro/packages/aqueous/PKGBUILD" \
  "$repo_root/distro/packages/matugen/PKGBUILD" \
  "$repo_root/distro/packages/pearl/dinx-first-run-wizard.c" \
  "$overlay/usr/share/pearl" \
  "$overlay/etc/pearl" \
  "$overlay/etc/skel/.config/pearl" \
  "$overlay/usr/local/libexec/dinx-pearl-shell" \
  "$overlay/usr/local/libexec/dinx-pearl-greeter-host" \
  "$overlay/usr/local/libexec/dinx-aqueous-pearl" \
  "$overlay/usr/local/libexec/dinx-aqueous-init"; do
  if [[ -e "$removed" ]]; then
    fail "retired theme payload is still present: $removed"
  fi
done
for retired in pearl aqueous dinx-pearl-themes dinx-aqueous matugen; do
  if grep -Eq "^[[:space:]]*- $retired$" "$profile"; then
    fail "profile still installs a retired theme package: $retired"
  fi
  if grep -Fq "\"$retired\"" "$feature_groups"; then
    fail "feature groups still list a retired theme package: $retired"
  fi
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

python - "$repo_root" "$brand_ray_source" "$brand_wordmark" \
  "$calamares_wordmark" "$calamares_ray" "$grub_logo" "$fastfetch_logo" "$boot_mark_source" <<'PY'
import pathlib
import struct
import sys
import xml.etree.ElementTree as ET

(root, ray_source_path, wordmark_path,
 cal_wordmark_path, cal_ray_path, grub_logo_path, fastfetch_logo_path, boot_mark_path) = map(pathlib.Path, sys.argv[1:])
brand = root / "design/brand/dinx-wordmark-compact.svg"
ns = "{http://www.w3.org/2000/svg}"
accent = "#F4515B"
stroke = {
    "fill": "none",
    "stroke": accent,
    "stroke-width": "29",
    "stroke-linecap": "round",
    "stroke-linejoin": "round",
}

source_root = ET.parse(brand).getroot()
source_d = source_root.find(f".//{ns}path")
assert source_d is not None, "compact DINX wordmark has no D path"
source_group = source_root.find(f".//{ns}g")
assert source_group is not None, "compact DINX wordmark has no shared stroke group"
for key, value in stroke.items():
    assert source_group.attrib.get(key) == value, f"source D has unexpected {key}"

def d_path(path):
    svg = ET.parse(path).getroot()
    element = svg.find(f".//{ns}path[@id='dinx-d']")
    assert element is not None, f"{path} has no reusable DINX D path"
    assert element.attrib.get("d") == source_d.attrib.get("d"), f"{path} D geometry differs from the compact wordmark"
    for key, value in stroke.items():
        assert element.attrib.get(key) == value, f"{path} D has unexpected {key}"
    return svg

wordmark = d_path(wordmark_path)
ray_source = d_path(ray_source_path)
assert ray_source.find(f".//{ns}path[@fill='{accent}']") is not None, "reduced D-ray source has no DINX coral bolt"
assert not ray_source.findall(f".//{ns}rect"), "reduced D-ray source paints an opaque background"
assert all(node.attrib.get("fill") != "#000000" for node in ray_source.iter()), "reduced D-ray source contains a black background fill"
assert cal_wordmark_path.read_bytes() == wordmark_path.read_bytes(), "Calamares wordmark diverges from DINX Linux artwork"
assert cal_ray_path.read_bytes() == ray_source_path.read_bytes(), "Calamares D-ray mark diverges from DINX artwork"
ascii_logo_lines = fastfetch_logo_path.read_text(encoding="ascii").splitlines()
assert 8 <= len(ascii_logo_lines) <= 20, "DINX D-ray ASCII logo has unexpected height"
assert 15 <= max(map(len, ascii_logo_lines)) <= 40, "DINX D-ray ASCII logo has unexpected width"
assert all(set(line) <= set(" .:-=+*#%@") for line in ascii_logo_lines), "DINX D-ray logo uses unsupported characters"
assert all(line == line.rstrip() for line in ascii_logo_lines), "DINX D-ray ASCII logo has trailing spaces"
assert any("@" in line for line in ascii_logo_lines) and any("#" in line for line in ascii_logo_lines), "DINX D-ray ASCII logo is missing density detail"


def png_info(path):
    data = path.read_bytes()
    assert data[:8] == bytes([137, 80, 78, 71, 13, 10, 26, 10]), f"{path} is not PNG"
    width, height = struct.unpack(">II", data[16:24])
    return width, height, data[25]

assert png_info(grub_logo_path) == (512, 512, 6), "GRUB DINX boot mark must be 512x512 RGBA"
PY



declare -A dark_token
while IFS='=' read -r name value; do
  dark_token["$name"]=$value
done < <(python - "$palette" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    values = json.load(stream)["dark"]

for key in (
    "mPrimary", "mOnPrimary", "mSecondary", "mError", "mSurface", "mOnSurface",
    "mSurfaceVariant", "mOnSurfaceVariant", "mOutline", "mHover", "mOnHover",
):
    print(f"{key}={values[key]}")
print(f"terminalYellow={values['terminal']['normal']['yellow']}")
PY
)

# --- the single remaining theme package ---------------------------------------
grep -Fqx '    - qt6ct' "$profile" || fail 'profile does not install qt6ct'
grep -Fqx '    - adw-gtk-theme' "$profile" || fail 'profile does not install adw-gtk-theme'
grep -Fqx '    - dinx-noto-latin' "$profile" || fail 'profile does not install the custom Noto Latin subset'
grep -Fqx '    - dinx-gtk-themes' "$profile" || fail 'profile does not install the DINX GTK theme package'
if grep -Fqx '    - dinx-pearl-themes' "$profile"; then
  fail 'profile still installs the retired theme package'
fi
grep -Fq 'pkgname=dinx-gtk-themes' "$gtk_themes_pkgbuild" || fail 'GTK theme package recipe is not dinx-gtk-themes'
grep -Fq "makedepends=('sassc' 'python')" "$gtk_themes_pkgbuild" \
  || fail 'GTK theme package no longer builds from SASS with the shell-free makedepends'
grep -Fq 'theme_dir="$pkgdir/usr/share/themes"' "$gtk_themes_pkgbuild" \
  || fail 'GTK theme package does not install into /usr/share/themes'
for gtk_theme_name in Orchis-Light Orchis-Dark Orchis-Square-Light Orchis-Square-Dark \
  Skeuos-Blue-Light Skeuos-Blue-Dark Skeuos-Blue-Light-Square Skeuos-Blue-Dark-Square \
  Fluent-Light Fluent-Dark Fluent-Square-Light Fluent-Square-Dark \
  Jasper-Light Jasper-Dark Jasper-Square-Light Jasper-Square-Dark; do
  grep -Fq "$gtk_theme_name" "$gtk_themes_pkgbuild" \
    || fail "GTK theme package does not ship the ported theme: $gtk_theme_name"
done
grep -Fq '"dinx-gtk-themes",' "$feature_groups" \
  || fail 'feature groups do not list the DINX GTK theme package'
if grep -Eiq 'pearl|matugen' "$gtk_themes_pkgbuild"; then
  fail 'GTK theme package recipe still depends on the retired shell theme stack'
fi

# --- fixed dark session defaults ----------------------------------------------
grep -Fqx 'export DINX_COLOR_SCHEME=dark' "$profile_shell" || fail 'DINX color scheme environment contract is missing'
grep -Fqx 'export DINTOR_THEME=prefer-dark' "$profile_shell" || fail 'DINX editor dark scheme contract is missing'
grep -Fqx 'export DINX_COLOR_SCHEME=dark' "$session_wrapper" || fail 'River session does not export the DINX dark scheme'
grep -Fqx 'export DINTOR_THEME=prefer-dark' "$session_wrapper" || fail 'River session does not export the dark editor scheme'
grep -Fqx 'export ADW_COLOR_SCHEME_FORCE_DARK=1' "$session_wrapper" || fail 'River session does not force dark libadwaita applications'
grep -Fqx "export GTK_THEME='DINX:dark'" "$profile_shell" || fail 'POSIX shell does not force the dark GTK theme'
grep -Fqx 'export QT_QPA_PLATFORMTHEME=qt6ct' "$session_wrapper" || fail 'River session does not force Qt6ct for GUI apps'
grep -Fq 'qt6ct/qt6ct.conf' "$session_wrapper" || fail 'River session does not seed the Qt6ct config for existing users'
grep -Fq 'qt6ct/colors/DINX.conf' "$session_wrapper" || fail 'River session does not seed the DINX Qt palette for existing users'
grep -Fq 'dinx-qt6ct-palette-seed' "$session_wrapper" \
  || fail 'River session does not safely migrate the stock Qt6ct palette'
[[ -x "$qt_palette_seed" ]] || fail 'Qt6ct palette seed helper is not executable'
sh -n "$qt_palette_seed" || fail 'Qt6ct palette seed helper has invalid shell syntax'
grep -Fq 'if [ -L "$target" ]; then' "$qt_palette_seed" \
  || fail 'Qt6ct palette seed helper may overwrite a user-managed symlink'
grep -Fq 'install -Dm644 "$seed" "$target"' "$qt_palette_seed" \
  || fail 'Qt6ct palette seed helper does not install the DINX palette'
if grep -Fq 'preferences.json' "$session_wrapper"; then
  fail 'River session still reads a saved shell theme selection'
fi
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/DINX.conf' "$qt" || fail 'Qt6ct does not consume DINX colors'
grep -Fq 'custom_palette=true' "$qt" || fail 'Qt6ct does not enable the DINX custom palette'
grep -Fq 'icon_theme=Papirus' "$qt" || fail 'Qt6ct default icon theme is not Papirus'
python - "$qt_palette" "$palette" <<'PY'
import configparser
import json
import sys

config = configparser.ConfigParser(interpolation=None)
config.read(sys.argv[1], encoding="utf-8")
with open(sys.argv[2], encoding="utf-8") as stream:
    tokens = json.load(stream)["dark"]

# Qt6ct serializes colors by QPalette::ColorRole numeric order.
roles = (
    "WindowText", "Button", "Light", "Midlight", "Dark", "Mid", "Text",
    "BrightText", "ButtonText", "Base", "Window", "Shadow", "Highlight",
    "HighlightedText", "Link", "LinkVisited", "AlternateBase", "NoRole",
    "ToolTipBase", "ToolTipText", "PlaceholderText",
)
active_roles = {
    "WindowText": "mOnSurface", "Button": "mSurfaceVariant", "Light": "mHover",
    "Midlight": "mOutline", "Dark": "mShadow", "Mid": "mSurface",
    "Text": "mOnSurface", "BrightText": "mError", "ButtonText": "mOnSurface",
    "Base": "mSurface", "Window": "mSurface", "Shadow": "mShadow",
    "Highlight": "mHover", "HighlightedText": "mOnHover", "Link": "mPrimary",
    "LinkVisited": "mTertiary", "AlternateBase": "mSurfaceVariant",
    "NoRole": "mSurface", "ToolTipBase": "mSurfaceVariant",
    "ToolTipText": "mOnSurface", "PlaceholderText": "mOnSurfaceVariant",
}
disabled_roles = {
    "WindowText": "mOnSurfaceVariant", "Button": "mSurfaceVariant",
    "Light": "mOutline", "Midlight": "mSurfaceVariant", "Dark": "mShadow",
    "Mid": "mSurface", "Text": "mOnSurfaceVariant",
    "BrightText": "mOnSurfaceVariant", "ButtonText": "mOnSurfaceVariant",
    "Base": "mSurfaceVariant", "Window": "mSurfaceVariant", "Shadow": "mShadow",
    "Highlight": "mHover", "HighlightedText": "mOnSurfaceVariant",
    "Link": "mOnSurfaceVariant", "LinkVisited": "mOnSurfaceVariant",
    "AlternateBase": "mSurfaceVariant", "NoRole": "mSurfaceVariant",
    "ToolTipBase": "mSurfaceVariant", "ToolTipText": "mOnSurfaceVariant",
    "PlaceholderText": "mOnSurfaceVariant",
}

def qt_color(token):
    return "#ff" + tokens[token][1:].lower()

for group, expected_roles in (
    ("active_colors", active_roles),
    ("inactive_colors", active_roles),
    ("disabled_colors", disabled_roles),
):
    colors = [color.strip().lower() for color in config["ColorScheme"][group].split(",")]
    if len(colors) != len(roles):
        raise SystemExit(f"{group} has {len(colors)} colors; expected {len(roles)} Qt palette roles")
    for index, role in enumerate(roles):
        expected = qt_color(expected_roles[role])
        if colors[index] != expected:
            raise SystemExit(f"{group} maps {role} to {colors[index]}, expected {expected}")
PY
grep -Fq "color-scheme='prefer-dark'" "$dconf_dark" || fail 'system dconf database does not default to the dark color scheme'
grep -Fq '[org/gnome/desktop/interface]' "$dconf_dark" || fail 'system dconf dark default has no interface schema'

# --- per-user synchronization driven by the DINX appearance file -------------
[[ -x "$theme_sync" ]] || fail 'GTK/Qt theme synchronizer is not executable'
sh -n "$theme_sync" || fail 'GTK/Qt theme synchronizer has invalid shell syntax'
grep -Fq 'appearance=$config_home/dinx/appearance.json' "$theme_sync" \
  || fail 'Theme sync does not read the DINX per-user appearance file'
grep -Fq 'gtk_theme=DINX' "$theme_sync" || fail 'Theme sync has no DINX default GTK theme'
for supported_family in Skeuos Orchis Fluent Jasper; do
  grep -Fq "$supported_family" "$theme_sync" \
    || fail "Theme sync cannot resolve the ported GTK family: $supported_family"
done
grep -Fq 'variant_suffix=Dark' "$theme_sync" || fail 'Theme sync cannot resolve dark variants'
grep -Fq -- '-Square' "$theme_sync" || fail 'Theme sync cannot resolve square corner variants'
grep -Fq 'gtk-application-prefer-dark-theme' "$theme_sync" || fail 'GTK dark preference is not synchronized'
grep -Fq 'dconf write' "$theme_sync" || fail 'GTK/libadwaita color-scheme is not synchronized'
grep -Fq "'prefer-dark'" "$theme_sync" || fail 'Theme sync does not write the dark dconf color-scheme'
grep -Fq 'theme_variant=dark' "$theme_sync" || fail 'Theme sync is not locked to the DINX dark variant'
grep -Fq 'custom_palette true' "$theme_sync" || fail 'Theme sync does not enable the DINX Qt palette'
grep -Fq 'colors/DINX.conf' "$theme_sync" || fail 'Theme sync does not consume the DINX Qt palette'
grep -Fq 'preserving user-managed symlink' "$theme_sync" || fail 'Theme sync does not preserve user-managed symlinks'
if grep -Eiq 'pearl|matugen' "$theme_sync"; then
  fail 'Theme sync still reads the retired shell theme catalog'
fi
for stale_input in 'preferences.json' 'last-good.json' 'gtk_drop_down_set_selected'; do
  if grep -Fq "$stale_input" "$theme_sync"; then
    fail "Theme sync still depends on retired shell input: $stale_input"
  fi
done

# --- consumers of the fixed dark appearance ----------------------------------
grep -Fq "scheme='DINX Dark'" "$haruna_wrapper" || fail 'Haruna does not select the fixed DINX dark scheme'
if grep -Fq 'preferences.json' "$haruna_wrapper"; then
  fail 'Haruna still reads the retired shell theme selection'
fi
[[ -x "$patchy_force_darkest" ]] || fail 'Patchy Darkest-theme helper is not executable'
sh -n "$patchy_force_darkest" || fail 'Patchy Darkest-theme helper has invalid shell syntax'
grep -Fq '/usr/lib/patchy/patchy-force-darkest' "$patchy_launcher" || fail 'Patchy does not force its internal Darkest theme'
grep -Fq 'export GTK_THEME=DINX' "$patchy_launcher" || fail 'Patchy does not launch with the DINX GTK theme'
grep -Fq 'export GTK_APPLICATION_PREFER_DARK_THEME=1' "$patchy_launcher" || fail 'Patchy does not prefer the dark GTK variant'
grep -Fq 'customThemeId=bundled:darkest.patchytheme' "$patchy_force_darkest" || fail 'Patchy internal theme is not forced to Darkest'
grep -Fq 'colorScheme=dark' "$patchy_force_darkest" || fail 'Patchy is not forced to the dark color scheme'
grep -Fq 'swayimg.gallery.window_color = 0xff0b0d12' "$swayimg" || fail 'Swayimg surface color is missing'
grep -Fq 'swayimg.text.font = "Noto Sans"' "$swayimg" || fail 'Swayimg font contract is missing'
grep -Fq 'swayimg.text.size = 10' "$swayimg" || fail 'Swayimg text size does not match Noto Sans 10'

# --- boot and installer branding ---------------------------------------------
grep -Fq 'item_font = "unicode 20"' "$grub" || fail 'GRUB menu font is not the readable Unicode font'
grep -Fq 'left = 37%' "$grub" || fail 'GRUB menu is not placed on the right of the logo'
grep -Fq 'left = 5%' "$grub" || fail 'GRUB logo is not placed on the left'
grep -Fq 'indicator.sprite.SetOpacity' "$plymouth_script" || fail 'Plymouth splash has no boot animation'
grep -Fq 'file = "logo.png"' "$grub" || fail 'GRUB theme does not display the DINX logo asset'
grep -Fq 'GRUB_DISTRIBUTOR="DINX"' "$grub_defaults" || fail 'GRUB menu distributor is not DINX'
grep -Fq 'GRUB_THEME="/usr/share/grub/themes/artix/theme.txt"' "$grub_defaults" || fail 'GRUB does not activate the DINX theme'
if grep -Eiq 'artix' "$grub"; then
  fail 'DINX GRUB theme retains Artix branding'
fi
grep -Fq 'file = "logo.png"' "$live_grub" || fail 'live ISO GRUB theme does not display the DINX logo'
grep -Fq 'GRUB_DISTRIBUTOR="DINX"' "$live_grub_defaults" || fail 'live ISO GRUB distributor is not DINX'
grep -Fq 'GRUB_THEME="/usr/share/grub/themes/artix/theme.txt"' "$live_grub_defaults" \
  || fail 'live ISO GRUB does not activate the DINX theme'
if grep -Eiq 'artix' "$live_grub"; then
  fail 'live ISO DINX GRUB theme retains Artix branding'
fi
cmp -s "$grub" "$live_grub" || fail 'live ISO and installed GRUB themes diverge'
cmp -s "$grub_logo" "$live_grub_logo" || fail 'live ISO and installed DINX boot marks differ'
grep -Fq 'set default=0' "$live_grub_cfg" || fail 'live ISO GRUB default is not the DINX boot option'
grep -Fq 'set timeout=6' "$live_grub_cfg" || fail 'live ISO GRUB timeout is not six seconds'
grep -Fq 'set timeout_style=menu' "$live_grub_cfg" || fail 'live ISO GRUB menu is not visible during timeout'

awk '
  /^rootfs:/ { in_rootfs = 1; next }
  /^livefs:/ { in_rootfs = 0 }
  in_rootfs && /^    - dinx-plymouth-theme$/ { found = 1 }
  END { exit !found }
' "$profile" || fail 'DINX Plymouth theme package is missing from the live rootfs profile'
grep -Fq 'set kopts="quiet splash"' "$live_grub_cfg" || fail 'live ISO GRUB does not enable Plymouth and quiet boot'
grep -Fq 'grub_theme=/boot/grub/themes/artix/theme.txt' "$live_grub_variable" \
  || fail 'live ISO GRUB does not select the DINX boot theme'
[[ $(grep -Fc 'menuentry ' "$live_grub_kernels") -eq 4 ]] \
  || fail 'live ISO GRUB does not define exactly the default, compatibility, safe-graphics and verbose DINX boot options'
grep -Fq 'menuentry "Start DINX Linux"' "$live_grub_kernels" \
  || fail 'DINX default boot option is missing'
grep -Fq 'menuentry "Start DINX Linux (compatibility)"' "$live_grub_kernels" \
  || fail 'DINX compatibility boot option is missing'
grep -Fq 'menuentry "Start DINX Linux (safe graphics)"' "$live_grub_kernels" \
  || fail 'DINX safe-graphics boot option is missing'
grep -Fqx '        linux /boot/vmlinuz-$2' "$live_grub_kernels" \
  || fail 'DINX default boot option does not use the stock kernel parameters'
grep -Fq 'linux /boot/vmlinuz-$2 noapic irqpoll' "$live_grub_kernels" \
  || fail 'DINX compatibility boot option does not pass the legacy interrupt parameters'
grep -Fq 'linux /boot/vmlinuz-$2 noapic irqpoll nomodeset plymouth.enable=0' "$live_grub_kernels" \
  || fail 'DINX safe-graphics boot option does not disable the GPU modeset and splash'
grep -Fq 'linux /boot/vmlinuz-$2 noapic irqpoll ignore_loglevel loglevel=8 plymouth.enable=0 vt.default_utf8=0' "$live_grub_kernels" \
  || fail 'DINX verbose boot option does not expose the full kernel console'
[[ $(grep -Fc 'menuentry ' "$live_grub_cfg") -eq 1 ]] \
  || fail 'live ISO GRUB has unexpected entries outside its single firmware option'
grep -Fq 'if [ "$grub_platform" = "efi" ]; then' "$live_grub_cfg" \
  || fail 'live ISO GRUB firmware option is not limited to UEFI'
grep -Fq 'menuentry "Boot to the Firmware/BIOS"' "$live_grub_cfg" \
  || fail 'live ISO GRUB firmware option is missing'
grep -Fq 'fwsetup' "$live_grub_cfg" || fail 'live ISO GRUB firmware option does not call fwsetup'
grep -Fq 'productIcon: "dinx-ray-mark.svg"' "$calamares_branding" || fail 'Calamares icon does not use the DINX D-ray mark'
grep -Fq 'productLogo: "dinx-emblem.png"' "$calamares_branding" || fail 'Calamares logo does not use the DINX emblem'
grep -Fq 'productWelcome: "dinx-emblem.png"' "$calamares_branding" || fail 'Calamares welcome does not use the DINX emblem'
grep -Fq "desktop-color: \"${dark_token[mSurface]}\"" "$grub" || fail 'GRUB surface does not use DINX background'
grep -Fq "selected_item_color = \"${dark_token[mPrimary]}\"" "$grub" || fail 'GRUB selection does not use DINX primary color'
if grep -Eq '^[[:space:]]*(desktop-image|menu_pixmap_style|selected_item_pixmap_style)[[:space:]]*=' "$grub"; then
  fail 'GRUB still uses an opaque/image-backed DINX-incompatible surface'
fi
grep -Fq 'Name=DINX' "$gtk_index" || fail 'GTK theme index name is missing'
grep -Fq 'IconTheme=Papirus' "$gtk_index" || fail 'DINX GTK theme does not select Papirus icons'
grep -Fqx '@import url("gtk.css");' "$gtk3_dark" || fail 'GTK3 dark theme bridge is missing'
grep -Fqx '@import url("gtk.css");' "$gtk4_dark" || fail 'GTK4 dark theme bridge is missing'
for gtk_settings in "$gtk3_settings" "$gtk4_settings" "$system_gtk3" "$system_gtk4"; do
  grep -Fq 'gtk-theme-name=Adwaita' "$gtk_settings" || fail "GTK settings omit the Adwaita theme: $gtk_settings"
  grep -Fq 'gtk-icon-theme-name=Papirus' "$gtk_settings" || fail "GTK settings omit the Papirus icon default: $gtk_settings"
  grep -Fq 'gtk-font-name=Noto Sans 10' "$gtk_settings" || fail "GTK settings omit Noto Sans 10: $gtk_settings"
  grep -Fq 'gtk-application-prefer-dark-theme=1' "$gtk_settings" || fail "GTK settings omit dark preference: $gtk_settings"
done
for gtk_theme in "$gtk3" "$gtk4"; do
  grep -Fq "background-color: ${dark_token[mSurface]}" "$gtk_theme" || fail "GTK theme lacks DINX surface: $gtk_theme"
  grep -Fq "color: ${dark_token[mOnSurface]}" "$gtk_theme" || fail "GTK theme lacks DINX foreground: $gtk_theme"
  grep -Fq "background-color: ${dark_token[mSurfaceVariant]}" "$gtk_theme" || fail "GTK theme lacks DINX control surface: $gtk_theme"
  grep -Fq "background-color: ${dark_token[mHover]}" "$gtk_theme" || fail "GTK theme lacks DINX hover state: $gtk_theme"
  grep -Fq "background-color: ${dark_token[mPrimary]}" "$gtk_theme" || grep -Fq "background-color: var(--accent);" "$gtk_theme" || fail "GTK theme lacks DINX primary state: $gtk_theme"
  grep -Fq 'font-family: Noto Sans;' "$gtk_theme" || fail "GTK theme font family is not Noto Sans: $gtk_theme"
  grep -Fq 'font-size: 10pt;' "$gtk_theme" || fail "GTK theme font size is not 10pt: $gtk_theme"
  if grep -Eq '#(31415d|151923|2859a8)' "$gtk_theme"; then
    fail "GTK theme contains an out-of-contract color: $gtk_theme"
  fi
done
grep -Fq 'border: 1px solid #3a4352' "$gtk3" \
  || fail 'GTK3 window border is not the neutral one-pixel DINX border'
grep -Fq -- '--border: #3a4352' "$gtk4" \
  || fail 'GTK4 border token is not the neutral DINX border'
grep -Fq 'border: 1px solid var(--border)' "$gtk4" \
  || fail 'GTK4 controls do not use the one-pixel border token'
grep -Fq '    .width = 1,' "$kwm_config" \
  || fail 'KWM window border is not one pixel'
grep -Fq "background: ${dark_token[mSurface]}" "$calamares" || fail 'Calamares surface does not use DINX background'
grep -Fq "background: ${dark_token[mSurfaceVariant]}" "$calamares" || fail 'Calamares control surface does not use DINX panel'
grep -Fq "background: ${dark_token[mHover]}" "$calamares" || fail 'Calamares hover state does not use DINX hover'
grep -Fq 'QMessageBox,' "$calamares" || fail 'Calamares error dialogs do not have an explicit dark surface'
grep -Fq 'QTextBrowser,' "$calamares" || fail 'Calamares diagnostic text does not have an explicit dark surface'
grep -Fq "        color: \"${dark_token[mSurface]}\"" "$calamares_notes" || fail 'Calamares install guidance does not paint a dark QML surface'
grep -Fq "            color: \"${dark_token[mOnSurface]}\"" "$calamares_notes" || fail 'Calamares install guidance text does not use DINX foreground'
grep -Fq "SidebarBackground: \"${dark_token[mSurfaceVariant]}\"" "$calamares_branding" || fail 'Calamares sidebar does not use DINX panel'
grep -Fq "SidebarText: \"${dark_token[mOnSurfaceVariant]}\"" "$calamares_branding" || fail 'Calamares sidebar text does not use DINX muted text'
grep -Fq "SidebarTextCurrent: \"${dark_token[mOnSurface]}\"" "$calamares_branding" || fail 'Calamares current sidebar text does not use DINX text'
grep -Fq "SidebarBackgroundCurrent: \"${dark_token[mHover]}\"" "$calamares_branding" || fail 'Calamares current sidebar does not use DINX hover'
grep -Fq 'font-family: Noto Sans;' "$calamares" || fail 'Calamares font family is not Noto Sans'
grep -Fq 'font-size: 10pt;' "$calamares" || fail 'Calamares font size is not 10pt'
if grep -Eq 'border-radius: [1-9]' "$calamares"; then
  fail 'Calamares uses rounded controls outside the DINX square geometry'
fi
if grep -Eq '#(31415d|151923|2859a8)' "$calamares"; then
  fail 'Calamares contains an out-of-contract color'
fi
for source in "$dinitui_source" "$dinxpanel_source"; do
  grep -Fq 'ADW_COLOR_SCHEME_FORCE_DARK' "$source" || fail "internal app does not force the DINX dark scheme: $source"
done
grep -Fq "background: ${dark_token[mSurface]}" "$dinitui_source" || fail 'DinitUI output surface does not use DINX background'
grep -Fq "color: ${dark_token[mOnSurface]}" "$dinitui_source" || fail 'DinitUI output text does not use DINX foreground'
grep -Fq "color: ${dark_token[mSecondary]}" "$dinitui_source" || fail 'DinitUI started state does not use DINX secondary'
grep -Fq "color: ${dark_token[terminalYellow]}" "$dinitui_source" || fail 'DinitUI transitional state does not use DINX terminal yellow'
grep -Fq "color: ${dark_token[mError]}" "$dinitui_source" || fail 'DinitUI failed state does not use DINX error'
grep -Fq "color: ${dark_token[mOnSurfaceVariant]}" "$dinitui_source" || fail 'DinitUI stopped state does not use DINX muted text'
grep -Fq "background-color: ${dark_token[mPrimary]}" "$dinitui_source" || fail 'DinitUI action does not use DINX primary'
grep -Fq "color: ${dark_token[mOnPrimary]}" "$dinitui_source" || fail 'DinitUI action text does not use DINX on-primary'
grep -Fq "background-color: ${dark_token[mHover]}" "$dinitui_source" || fail 'DinitUI selection does not use DINX hover'
grep -Fq "border-color: ${dark_token[mOutline]}" "$dinitui_source" || fail 'DinitUI controls do not use DINX outline'
grep -Fq "background: ${dark_token[mSurface]}" "$dinxpanel_source" || fail 'DINXPanel output surface does not use DINX background'
grep -Fq "color: ${dark_token[mOnSurface]}" "$dinxpanel_source" || fail 'DINXPanel output text does not use DINX foreground'
grep -Fq "background-color: ${dark_token[mPrimary]}" "$dinxpanel_source" || fail 'DINXPanel action does not use DINX primary'
grep -Fq "color: ${dark_token[mOnPrimary]}" "$dinxpanel_source" || fail 'DINXPanel action text does not use DINX on-primary'
printf 'dinx_theme_contract session=river appearance_selectable=true dark_default=true palette=true static=true typography=true states=true gtk=true gtk_system=true gtk_package=true qt=true qt_palette=true qt_session_seed=true dconf_scheme=true theme_sync_input=appearance.json theme_families=DINX+Skeuos+Orchis+Fluent+Jasper patchy_darkest=true swayimg=true haruna_dark=true no_pearl=true grub=true calamares=true branding=true wordmark_d_geometry=true ascii_logo=true boot_mark=true\n'
