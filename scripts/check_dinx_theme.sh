#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
palette="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/theme/DINX.json"
profile_shell="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
pearl_greeter="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/pearl/greeter.json"
pearl_pkg="$repo_root/distro/packages/pearl/PKGBUILD"
grub="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/grub/themes/artix/theme.txt"
calamares="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/stylesheet.qss"
calamares_branding="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/branding.desc"
qt="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/qt6ct.conf"
qt_palette="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
brand_wordmark="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/branding/dinx-linux-logo.svg"
brand_ray="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/branding/dinx-ray-mark.svg"
fastfetch_logo="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/branding/dinx-ray-mark.txt"
brand_wallpaper="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/branding/dinx-wallpaper.png"
calamares_wordmark="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/dinx.svg"
calamares_ray="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/dinx-ray-mark.svg"
pearl_preferences="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/pearl/preferences.json"
grub_logo="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/usr/share/grub/themes/artix/logo.png"
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
swayimg="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/swayimg/init.lua"
fail() {
  printf 'check_dinx_theme: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$palette" "$profile_shell" "$pearl_greeter" "$pearl_pkg" \
  "$grub" "$grub_logo" "$calamares" "$calamares_branding" "$calamares_wordmark" \
  "$calamares_ray" "$brand_wordmark" "$brand_ray" "$brand_wallpaper" "$pearl_preferences" "$fastfetch_logo" \
  "$qt" "$qt_palette" "$swayimg" "$dinitui_source" "$dinxpanel_source" \
  "$seafoam_settings_source" "$gtk_index" "$gtk3" "$gtk3_dark" "$gtk4" "$gtk4_dark" \
  "$gtk3_settings" "$gtk4_settings" "$system_gtk3" "$system_gtk4" "$session_wrapper"; do
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

python - "$repo_root" "$pearl_greeter" "$pearl_preferences" "$brand_wordmark" "$brand_ray" \
  "$calamares_wordmark" "$calamares_ray" "$brand_wallpaper" "$grub_logo" "$fastfetch_logo" <<'PY'
import json
import pathlib
import struct
import sys
import xml.etree.ElementTree as ET

(root, greeter_path, prefs_path, wordmark_path, ray_path, cal_wordmark_path, cal_ray_path,
 wallpaper_path, grub_logo_path, fastfetch_logo_path) = map(pathlib.Path, sys.argv[1:])
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
ray = d_path(ray_path)
assert ray.find(f".//{ns}path[@fill='{accent}']") is not None, "D-ray mark has no DINX coral ray"
assert cal_wordmark_path.read_bytes() == wordmark_path.read_bytes(), "Calamares wordmark diverges from DINX Linux artwork"
assert cal_ray_path.read_bytes() == ray_path.read_bytes(), "Calamares D-ray mark diverges from DINX artwork"
ascii_logo_lines = fastfetch_logo_path.read_text(encoding="ascii").splitlines()
assert 8 <= len(ascii_logo_lines) <= 20, "DINX D-ray ASCII logo has unexpected height"
assert 15 <= max(map(len, ascii_logo_lines)) <= 40, "DINX D-ray ASCII logo has unexpected width"
assert all(set(line) <= set(" .:-=+*#%@") for line in ascii_logo_lines), "DINX D-ray logo uses unsupported characters"
assert all(line == line.rstrip() for line in ascii_logo_lines), "DINX D-ray ASCII logo has trailing spaces"
assert any("@" in line for line in ascii_logo_lines) and any("#" in line for line in ascii_logo_lines), "DINX D-ray ASCII logo is missing density detail"


greeter = json.loads(greeter_path.read_text())
expected_wallpaper = "/usr/share/dinx/branding/dinx-wallpaper.png"
assert greeter.get("wallpaper") == expected_wallpaper and greeter.get("wallpaper_fit") == "cover", "Pearl Greeter does not use the DINX wallpaper"
preferences = json.loads(prefs_path.read_text())
assert preferences.get("wallpaper", {}).get("path") == expected_wallpaper, "fresh Pearl preferences do not use the DINX wallpaper"
desktop_icons = preferences.get("desktop_icons", {})
assert desktop_icons.get("enabled") is True, "DINX wallpaper seed unexpectedly disables desktop icons"
assert not {"icon", "icons", "icon_theme", "iconTheme"} & desktop_icons.keys(), "desktop icon preferences contain a branding override"
assert not {"icon_theme", "iconTheme"} & preferences.keys(), "DINX preferences override the desktop icon theme"

def png_dimensions(path):
    data = path.read_bytes()
    assert data[:8] == bytes([137, 80, 78, 71, 13, 10, 26, 10]), f"{path} is not PNG"
    width, height = struct.unpack(">II", data[16:24])
    return width, height

assert png_dimensions(wallpaper_path) == (1920, 1080), "DINX wallpaper has unexpected dimensions"
assert png_dimensions(grub_logo_path) == (512, 512), "GRUB D-ray logo has unexpected dimensions"
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
grep -Fqx '    - noto-fonts' "$profile" || fail 'profile does not install Noto fonts'
grep -Fq 'DINX_COLOR_SCHEME="${DINX_COLOR_SCHEME:-dark}"' "$profile_shell" || fail 'DINX color scheme environment contract is missing'
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/DINX.conf' "$qt" || fail 'Qt6ct does not consume DINX colors'
grep -Fq 'active_colors=#ff0b0d12, #ffd7dde8' "$qt_palette" || fail 'Qt6ct DINX palette omits dark surfaces or foreground text'
grep -Fq '"theme": "gtk"' "$pearl_greeter" || fail 'Pearl Greeter does not use the GTK theme bridge'
grep -Fq '"gtk_theme": "DINX"' "$pearl_greeter" || fail 'Pearl Greeter does not use the DINX GTK theme'
grep -Fq '"wallpaper_color": "#0b0d12"' "$pearl_greeter" || fail 'Pearl Greeter surface color is missing'
grep -Fq '"font_size": 16' "$pearl_greeter" || fail 'Pearl Greeter font size is missing'
grep -Fq '"force_session": "wayland:dinx-aqueous-pearl.desktop"' "$pearl_greeter" \
  || fail 'Pearl Greeter does not force the DINX Aqueous/Pearl session'
grep -Fq '"allow_uwsm": false' "$pearl_greeter" || fail 'Pearl Greeter UWSM integration is not disabled'
grep -Fq '"x11": false' "$pearl_greeter" || fail 'Pearl Greeter X11 integration is not disabled'
grep -Fq '"wallpaper": "/usr/share/dinx/branding/dinx-wallpaper.png"' "$pearl_greeter" \
  || fail 'Pearl Greeter does not use the DINX wallpaper asset'
grep -Fq '"wallpaper_fit": "cover"' "$pearl_greeter" || fail 'Pearl Greeter DINX wallpaper fit is incorrect'
grep -Fq 'file = "logo.png"' "$grub" || fail 'GRUB theme does not display the DINX logo asset'
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
  grep -Fq 'gtk-theme-name=DINX' "$gtk_settings" || fail "GTK settings omit DINX theme: $gtk_settings"
  grep -Fq 'gtk-icon-theme-name=Adwaita' "$gtk_settings" || fail "GTK settings override upstream icons: $gtk_settings"
  grep -Fq 'gtk-font-name=Noto Sans 10' "$gtk_settings" || fail "GTK settings omit Noto Sans 10: $gtk_settings"
  grep -Fq 'gtk-application-prefer-dark-theme=1' "$gtk_settings" || fail "GTK settings omit dark preference: $gtk_settings"
done
grep -Fq 'export GTK_THEME="DINX:dark"' "$session_wrapper" || fail 'Aqueous session does not force the DINX dark GTK variant'
grep -Fq 'export QT_QPA_PLATFORMTHEME=qt6ct' "$session_wrapper" || fail 'Aqueous session does not force Qt6ct for GUI apps'
grep -Fq 'qt6ct/qt6ct.conf' "$session_wrapper" || fail 'Aqueous session does not seed the Qt6ct config for existing users'
grep -Fq 'qt6ct/colors/DINX.conf' "$session_wrapper" || fail 'Aqueous session does not seed the DINX Qt palette for existing users'
grep -Fq 'pearl/preferences.json' "$session_wrapper" || fail 'Aqueous session does not seed DINX Pearl wallpaper preferences for missing files'
grep -Fq '[ ! -e "$config_home/pearl/preferences.json" ]' "$session_wrapper" \
  || fail 'Aqueous session may overwrite existing Pearl preferences'
grep -Fq '[ ! -e "$config_home/pearl/last-good.json" ]' "$session_wrapper" \
  || fail 'Aqueous session overwrites Pearl recovery state while seeding the wallpaper'
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
grep -Fq 'IconTheme=Adwaita' "$gtk_index" || fail 'DINX icon theme bridge is missing'
grep -Fqx '@import url("gtk.css");' "$gtk3_dark" || fail 'GTK3 dark theme bridge is missing'
grep -Fqx '@import url("gtk.css");' "$gtk4_dark" || fail 'GTK4 dark theme bridge is missing'
grep -Fq 'swayimg.gallery.window_color = 0xff0b0d12' "$swayimg" || fail 'Swayimg surface color is missing'
grep -Fq 'swayimg.text.font = "Noto Sans"' "$swayimg" || fail 'Swayimg font contract is missing'
grep -Fq 'swayimg.text.size = 10' "$swayimg" || fail 'Swayimg text size does not match Noto Sans 10'
printf 'dinx_theme_contract palette=true static=true typography=true states=true gtk=true gtk_system=true qt=true qt_palette=true qt_session_seed=true swayimg=true pearl_greeter=true grub=true calamares=true branding=true wordmark_d_geometry=true ascii_logo=true desktop_icons_upstream=true\n'
