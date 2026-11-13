#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
palette="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/theme/DINX.json"
profile_shell="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
pearl_greeter="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/pearl/greeter.json"
pearl_pkg="$repo_root/distro/packages/pearl/PKGBUILD"
grub="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/grub/themes/artix/theme.txt"
grub_defaults="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/default/grub.d/10-dinx-branding.cfg"
live_grub="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/themes/artix/theme.txt"
live_grub_defaults="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/etc/default/grub"
live_grub_logo="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/themes/artix/logo.png"
live_grub_cfg="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/cfg/grub.cfg"
live_grub_kernels="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/cfg/kernels.cfg"
live_grub_variable="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/usr/share/grub/cfg/variable.cfg"
calamares="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/stylesheet.qss"
calamares_notes="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/notesqml.qml"
calamares_branding="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/branding.desc"
qt="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/qt6ct.conf"
qt_palette="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
qt_palette_seed="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-qt6ct-palette-seed"
brand_wordmark="$repo_root/design/brand/dinx-linux-logo.svg"
cli_issue="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/issue"
live_cli_issue="$repo_root/distro/iso/iso-profiles/dinx/live-overlay/etc/issue"
brand_ray_source="$repo_root/design/brand/dinx-ray-mark.svg"
fastfetch_logo="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/branding/dinx-ray-mark.txt"
calamares_wordmark="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/dinx.svg"
calamares_ray="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/dinx-ray-mark.svg"
pearl_preferences="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/pearl/preferences.json"
grub_logo="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/grub/themes/artix/logo.png"
boot_mark_source="$repo_root/design/brand/dinx-boot-mark.svg"
dinitui_source="$repo_root/distro/packages/dinitui/src/main.zig"
dinxpanel_source="$repo_root/distro/packages/dinxpanel/src/main.zig"
seafoam_settings_source="$repo_root/distro/packages/seafoam-settings/src/main.zig"
gtk_index="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/index.theme"
gtk3="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-3.0/gtk.css"
gtk3_dark="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-3.0/gtk-dark.css"
gtk4="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-4.0/gtk.css"
gtk4_dark="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/themes/DINX/gtk-4.0/gtk-dark.css"
gtk3_settings="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/gtk-3.0/settings.ini"
gtk4_settings="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/gtk-4.0/settings.ini"
system_gtk3="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/gtk-3.0/settings.ini"
system_gtk4="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/gtk-4.0/settings.ini"
session_wrapper="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-aqueous-pearl"
pearl_shell="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-pearl-shell"
theme_sync="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"
patchy_launcher="$repo_root/distro/packages/patchy/patchy"
patchy_force_darkest="$repo_root/distro/packages/patchy/patchy-force-darkest"
wizard_source="$repo_root/distro/packages/pearl/dinx-first-run-wizard.c"
swayimg="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/swayimg/init.lua"
fail() {
  printf 'check_dinx_theme: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$palette" "$profile_shell" "$pearl_greeter" "$pearl_pkg" \
  "$grub" "$grub_defaults" "$grub_logo" "$boot_mark_source" "$calamares" "$calamares_notes" "$calamares_branding" "$calamares_wordmark" \
  "$calamares_ray" "$brand_wordmark" "$brand_ray_source" "$pearl_preferences" "$fastfetch_logo" "$cli_issue" \
  "$qt" "$qt_palette" "$swayimg" "$dinitui_source" "$dinxpanel_source" \
  "$seafoam_settings_source" "$gtk_index" "$gtk3" "$gtk3_dark" "$gtk4" "$gtk4_dark" \
  "$gtk3_settings" "$gtk4_settings" "$system_gtk3" "$system_gtk4" "$session_wrapper" "$pearl_shell" "$wizard_source" "$qt_palette_seed" "$theme_sync" "$patchy_launcher" "$patchy_force_darkest"; do
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

python - "$repo_root" "$brand_ray_source" "$pearl_greeter" "$pearl_preferences" "$brand_wordmark" \
  "$calamares_wordmark" "$calamares_ray" "$grub_logo" "$fastfetch_logo" "$boot_mark_source" <<'PY'
import json
import pathlib
import struct
import sys
import xml.etree.ElementTree as ET

(root, ray_source_path, greeter_path, prefs_path, wordmark_path,
 cal_wordmark_path, cal_ray_path, grub_logo_path, fastfetch_logo_path, boot_mark_path) = map(pathlib.Path, sys.argv[1:])
brand = root / "design/brand/dinx-wordmark-compact.svg"
ns = "{http://www.w3.org/2000/svg}"
boot_mark = ET.parse(boot_mark_path).getroot()
assert boot_mark.tag == f"{ns}svg", "DINX boot mark source is not SVG"
assert boot_mark.attrib.get("viewBox") == "0 0 512 512", "DINX boot mark has unexpected dimensions"
boot_title = boot_mark.find(f"{ns}title")
assert boot_title is not None and boot_title.text == "DINX boot mark", "DINX boot mark source title is missing"
assert boot_mark.find(f".//{ns}linearGradient") is not None, "DINX boot mark gradient is missing"
assert len(boot_mark.findall(f".//{ns}path")) == 2, "DINX boot mark paths are incomplete"
assert not boot_mark.findall(f".//{ns}rect"), "DINX boot mark paints an opaque background"
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


greeter = json.loads(greeter_path.read_text())
assert "wallpaper" not in greeter and "wallpaper_fit" not in greeter and "logo" not in greeter, "Pearl Greeter still configures a wallpaper or logo"
assert greeter.get("wallpaper_color") == "#0b0d12", "Pearl Greeter solid surface color is missing"
preferences = json.loads(prefs_path.read_text())
wallpaper = preferences.get("wallpaper", {})
assert wallpaper.get("mode") == "solid" and wallpaper.get("path") == "", "fresh Pearl preferences still select a wallpaper image"
assert preferences.get("bar", {}).get("edge") == "top", "Pearl default bar position is not top"
assert preferences.get("dock", {}).get("enabled") is True and preferences.get("dock", {}).get("edge") == "bottom", "Pearl default dock configuration is incorrect"
desktop_icons = preferences.get("desktop_icons", {})
assert desktop_icons.get("enabled") is True, "Pearl seed unexpectedly disables desktop icons"
assert not {"icon", "icons", "icon_theme", "iconTheme"} & desktop_icons.keys(), "desktop icon preferences contain a branding override"
assert not {"icon_theme", "iconTheme"} & preferences.keys(), "DINX preferences override the desktop icon theme"

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

grep -Fqx '    - qt6ct' "$profile" || fail 'profile does not install qt6ct'
grep -Fqx '    - adw-gtk-theme' "$profile" || fail 'profile does not install adw-gtk-theme'
grep -Fqx '    - dinx-noto-latin' "$profile" || fail 'profile does not install the custom Noto Latin subset'
grep -Fq 'DINX_COLOR_SCHEME="${DINX_COLOR_SCHEME:-dark}"' "$profile_shell" || fail 'DINX color scheme environment contract is missing'
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/DINX.conf' "$qt" || fail 'Qt6ct does not consume DINX colors'
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
grep -Fq '"theme": "gtk"' "$pearl_greeter" || fail 'Pearl Greeter does not use the GTK theme bridge'
grep -Fq '"gtk_theme": "Adwaita"' "$pearl_greeter" || fail 'Pearl Greeter does not use the GTK Adwaita theme'
grep -Fq '"wallpaper_color": "#0b0d12"' "$pearl_greeter" || fail 'Pearl Greeter surface color is missing'
grep -Fq '"font_size": 16' "$pearl_greeter" || fail 'Pearl Greeter font size is missing'
grep -Fq '"force_session": "wayland:dinx-aqueous-pearl.desktop"' "$pearl_greeter" \
  || fail 'Pearl Greeter does not force the DINX Aqueous/Pearl session'
grep -Fq '"allow_uwsm": false' "$pearl_greeter" || fail 'Pearl Greeter UWSM integration is not disabled'
grep -Fq '"x11": false' "$pearl_greeter" || fail 'Pearl Greeter X11 integration is not disabled'
if grep -Eq '"(wallpaper|wallpaper_fit|logo)"[[:space:]]*:' "$pearl_greeter"; then
  fail 'Pearl Greeter still configures its wallpaper image or logo'
fi
grep -Fq '"mode": "solid"' "$pearl_preferences" || fail 'Fresh Pearl preferences enable an image wallpaper'
grep -Fq '"path": ""' "$pearl_preferences" || fail 'Fresh Pearl preferences retain an image wallpaper path'
grep -Fq 'file = "logo.png"' "$grub" || fail 'GRUB theme does not display the DINX logo asset'
jq -e '.theme.mode == "static" and .theme.variant == "dark" and .theme.gtk_name == ""' "$pearl_preferences" >/dev/null \
  || fail 'Fresh Pearl preferences do not default to Pearl Material dark'
grep -Fq 'const char *theme_name[] = { "dinx-dark", "dinx-light", "material-dark", "material-light" };' "$wizard_source" \
  || fail 'Pearl first-run theme selection order changed'
grep -Fq 'gtk_drop_down_set_selected(GTK_DROP_DOWN(wizard->theme), 2);' "$wizard_source" \
  || fail 'Pearl first-run wizard does not default to Pearl Material dark'
wizard_sha256=$(sha256sum "$wizard_source" | cut -d ' ' -f 1)
grep -Fq "'$wizard_sha256'" "$pearl_pkg" || fail 'Pearl first-run wizard source checksum is stale'
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
[[ $(grep -Fc 'menuentry ' "$live_grub_kernels") -eq 1 ]] \
  || fail 'live ISO GRUB does not define exactly one default DINX boot option'
grep -Fq 'menuentry "Start DINX Linux"' "$live_grub_kernels" \
  || fail 'DINX default boot option is missing'
[[ $(grep -Fc 'menuentry ' "$live_grub_cfg") -eq 1 ]] \
  || fail 'live ISO GRUB has unexpected entries outside its single firmware option'
grep -Fq 'if [ "$grub_platform" = "efi" ]; then' "$live_grub_cfg" \
  || fail 'live ISO GRUB firmware option is not limited to UEFI'
grep -Fq 'menuentry "Boot to the Firmware/BIOS"' "$live_grub_cfg" \
  || fail 'live ISO GRUB firmware option is missing'
grep -Fq 'fwsetup' "$live_grub_cfg" || fail 'live ISO GRUB firmware option does not call fwsetup'
grep -Fq 'productIcon: "dinx-ray-mark.svg"' "$calamares_branding" || fail 'Calamares icon does not use the DINX D-ray mark'
grep -Fq 'productLogo: "dinx.svg"' "$calamares_branding" || fail 'Calamares logo does not use the DINX Linux wordmark'
grep -Fq 'productWelcome: "dinx.svg"' "$calamares_branding" || fail 'Calamares welcome does not use the DINX Linux wordmark'
if grep -Eiq 'systemd|systemctl' "$pearl_greeter"; then
  fail 'Pearl Greeter configuration contains a systemd integration'
fi
grep -Fq 'build-greeter' "$pearl_pkg" || fail 'Pearl Greeter is not built by the package'
grep -Fq 'pearl-greeter-host' "$pearl_pkg" || fail 'Pearl Greeter host is not packaged'
grep -Fq 'rm -rf "$pkgdir/usr/lib/systemd" "$pkgdir/usr/share/uwsm"' "$pearl_pkg" \
  || fail 'Pearl upstream lifecycle payloads are not removed'
for gtk_settings in "$gtk3_settings" "$gtk4_settings" "$system_gtk3" "$system_gtk4"; do
  grep -Fq 'gtk-theme-name=Adwaita' "$gtk_settings" || fail "GTK settings omit the Adwaita theme: $gtk_settings"
  grep -Fq 'gtk-icon-theme-name=Papirus' "$gtk_settings" || fail "GTK settings omit the Papirus icon default: $gtk_settings"
  grep -Fq 'gtk-font-name=Noto Sans 10' "$gtk_settings" || fail "GTK settings omit Noto Sans 10: $gtk_settings"
  grep -Fq 'gtk-application-prefer-dark-theme=1' "$gtk_settings" || fail "GTK settings omit dark preference: $gtk_settings"
done
if grep -Eq 'GTK_THEME=' "$session_wrapper" "$profile_shell"; then
  fail 'DINX session overrides the GTK theme selected by applications'
fi
grep -Fq 'export QT_QPA_PLATFORMTHEME=qt6ct' "$session_wrapper" || fail 'Aqueous session does not force Qt6ct for GUI apps'
grep -Fq 'qt6ct/qt6ct.conf' "$session_wrapper" || fail 'Aqueous session does not seed the Qt6ct config for existing users'
grep -Fq 'qt6ct/colors/DINX.conf' "$session_wrapper" || fail 'Aqueous session does not seed the DINX Qt palette for existing users'
grep -Fq 'dinx-qt6ct-palette-seed' "$session_wrapper" \
  || fail 'Aqueous session does not safely migrate the stock Qt6ct palette'
grep -Fq 'pearl/preferences.json' "$session_wrapper" || fail 'Aqueous session does not seed Pearl preferences for missing files'
grep -Fq '[ ! -e "$config_home/pearl/preferences.json" ]' "$session_wrapper" \
  || fail 'Aqueous session may overwrite existing Pearl preferences'
grep -Fq '[ ! -e "$config_home/pearl/last-good.json" ]' "$session_wrapper" \
  || fail 'Aqueous session may overwrite Pearl recovery state'
grep -Fq 'icon_theme=Papirus' "$qt" || fail 'Qt6ct default icon theme is not Papirus'
[[ -x "$theme_sync" ]] || fail 'GTK/Qt theme synchronizer is not executable'
sh -n "$theme_sync" || fail 'GTK/Qt theme synchronizer has invalid shell syntax'
grep -Fq 'dinx-sync-session-theme' "$pearl_shell" || fail 'Pearl shell does not synchronize toolkit appearance'
grep -Fq 'gtk-application-prefer-dark-theme' "$theme_sync" || fail 'GTK dark preference is not synchronized'
grep -Fq 'custom_palette true' "$theme_sync" || fail 'Qt dark palette is not enabled for dark Pearl mode'
grep -Fq 'custom_palette false' "$theme_sync" || fail 'Qt custom palette is not disabled for light Pearl mode'
[[ -x "$patchy_force_darkest" ]] || fail 'Patchy Darkest-theme helper is not executable'
sh -n "$patchy_force_darkest" || fail 'Patchy Darkest-theme helper has invalid shell syntax'
grep -Fq '/usr/lib/patchy/patchy-force-darkest' "$patchy_launcher" || fail 'Patchy does not force its internal Darkest theme'
grep -Fq 'customThemeId=bundled:darkest.patchytheme' "$patchy_force_darkest" || fail 'Patchy internal theme is not forced to Darkest'
sh -n "$pearl_shell" || fail 'Pearl shell wrapper has invalid shell syntax'
grep -Fq 'DINX_FIRST_RUN_WIZARD' "$pearl_shell" || fail 'Pearl shell wrapper lacks a testable wizard path'
grep -Fq "desktop-color: \"${dark_token[mSurface]}\"" "$grub" || fail 'GRUB surface does not use DINX background'
grep -Fq "selected_item_color = \"${dark_token[mPrimary]}\"" "$grub" || fail 'GRUB selection does not use DINX primary color'
if grep -Eq '^[[:space:]]*(desktop-image|menu_pixmap_style|selected_item_pixmap_style)[[:space:]]*=' "$grub"; then
  fail 'GRUB still uses an opaque/image-backed DINX-incompatible surface'
fi
for gtk_theme in "$gtk3" "$gtk4"; do
  grep -Fq "background-color: ${dark_token[mSurface]}" "$gtk_theme" || fail "GTK theme lacks DINX surface: $gtk_theme"
  grep -Fq "color: ${dark_token[mOnSurface]}" "$gtk_theme" || fail "GTK theme lacks DINX foreground: $gtk_theme"
  grep -Fq "background-color: ${dark_token[mSurfaceVariant]}" "$gtk_theme" || fail "GTK theme lacks DINX control surface: $gtk_theme"
  grep -Fq "background-color: ${dark_token[mHover]}" "$gtk_theme" || fail "GTK theme lacks DINX hover state: $gtk_theme"
  grep -Fq "background-color: ${dark_token[mPrimary]}" "$gtk_theme" || fail "GTK theme lacks DINX primary state: $gtk_theme"
  grep -Fq 'font-family: Noto Sans;' "$gtk_theme" || fail "GTK theme font family is not Noto Sans: $gtk_theme"
  grep -Fq 'font-size: 10pt;' "$gtk_theme" || fail "GTK theme font size is not 10pt: $gtk_theme"
  if grep -Eq '#(31415d|151923|2859a8)' "$gtk_theme"; then
    fail "GTK theme contains an out-of-contract color: $gtk_theme"
  fi
done
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
grep -Fq "background: ${dark_token[mSurface]}" "$seafoam_settings_source" || fail 'Seafoam Settings surface does not use DINX background'
grep -Fq "color: ${dark_token[mOnSurface]}" "$seafoam_settings_source" || fail 'Seafoam Settings text does not use DINX foreground'
grep -Fq "background-color: ${dark_token[mPrimary]}" "$seafoam_settings_source" || fail 'Seafoam Settings action does not use DINX primary'
grep -Fq 'Name=DINX' "$gtk_index" || fail 'GTK theme index name is missing'
grep -Fq 'IconTheme=Papirus' "$gtk_index" || fail 'DINX GTK theme does not select Papirus icons'
grep -Fqx '@import url("gtk.css");' "$gtk3_dark" || fail 'GTK3 dark theme bridge is missing'
grep -Fqx '@import url("gtk.css");' "$gtk4_dark" || fail 'GTK4 dark theme bridge is missing'
grep -Fq 'swayimg.gallery.window_color = 0xff0b0d12' "$swayimg" || fail 'Swayimg surface color is missing'
grep -Fq 'swayimg.text.font = "Noto Sans"' "$swayimg" || fail 'Swayimg font contract is missing'
grep -Fq 'swayimg.text.size = 10' "$swayimg" || fail 'Swayimg text size does not match Noto Sans 10'
printf 'dinx_theme_contract palette=true static=true typography=true states=true gtk=true gtk_system=true qt=true qt_palette=true qt_session_seed=true patchy_darkest=true swayimg=true pearl_greeter=true grub=true calamares=true branding=true wordmark_d_geometry=true ascii_logo=true desktop_icons_upstream=true boot_mark=true\n'
