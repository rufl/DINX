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
calamares_branding="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/branding.desc"
qt="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/qt6ct.conf"
swayimg="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/swayimg/init.lua"
labwc="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/labwc/rc.xml"
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
fail() {
  printf 'check_dinx_theme: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$noctalia_config" "$palette" "$profile_shell" "$greeter" \
  "$greeter_launcher" "$grub" "$calamares" "$calamares_branding" "$qt" "$swayimg" "$labwc" \
  "$dinitui_source" "$dinxpanel_source" "$seafoam_settings_source" "$gtk_index" \
  "$gtk3" "$gtk3_dark" "$gtk4" "$gtk4_dark" "$gtk3_settings" "$gtk4_settings"; do
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
grep -Fqx '    - cantarell-fonts' "$profile" || fail 'profile does not install Cantarell fonts'
grep -Fq 'source = "custom"' "$noctalia_config" || fail 'Noctalia custom palette source is missing'
grep -Fq 'custom_palette = "DINX"' "$noctalia_config" || fail 'Noctalia DINX palette selection is missing'
grep -Fq 'builtin_ids = ["btop", "foot", "ghostty", "gtk3", "gtk4", "kcolorscheme", "qt"]' "$noctalia_config" || fail 'Noctalia application template set is incomplete'
grep -Fq 'font_family = "Cantarell"' "$noctalia_config" || fail 'Noctalia font contract is missing'
grep -Fq '<font name="Cantarell" size="11" />' "$labwc" || fail 'labwc font contract is missing'
grep -Fq 'theme_name = "DINX"' "$greeter" || fail 'ReGreet does not use DINX theme'
grep -Fq 'font_name = "Cantarell 11"' "$greeter" || fail 'ReGreet font contract is missing'
grep -Fq 'GTK_THEME="${GTK_THEME:-DINX:dark}"' "$greeter_launcher" || fail 'ReGreet launcher does not force DINX fallback theme'
grep -Fq 'QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"' "$profile_shell" || fail 'Qt6ct session adapter is missing'
grep -Fq 'NOCTALIA_COLOR_SCHEME="${NOCTALIA_COLOR_SCHEME:-dark}"' "$profile_shell" || fail 'Noctalia color scheme environment contract is missing'
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/noctalia.conf' "$qt" || fail 'Qt6ct does not consume Noctalia colors'
grep -Fq 'general="Cantarell,11' "$qt" || fail 'Qt6ct GUI font does not match Cantarell 11'
for gtk_settings in "$gtk3_settings" "$gtk4_settings"; do
  grep -Fq 'gtk-theme-name=DINX' "$gtk_settings" || fail "GTK settings omit DINX theme: $gtk_settings"
  grep -Fq 'gtk-font-name=Cantarell 11' "$gtk_settings" || fail "GTK settings omit Cantarell 11: $gtk_settings"
done
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
  grep -Fq 'font-family: Cantarell;' "$gtk_theme" || fail "GTK theme font family is not Cantarell: $gtk_theme"
  grep -Fq 'font-size: 11pt;' "$gtk_theme" || fail "GTK theme font size is not 11pt: $gtk_theme"
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
grep -Fq 'font-family: Cantarell;' "$calamares" || fail 'Calamares font family is not Cantarell'
grep -Fq 'font-size: 11pt;' "$calamares" || fail 'Calamares font size is not 11pt'
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
grep -Fq 'swayimg.text.font = "Cantarell"' "$swayimg" || fail 'Swayimg font contract is missing'
grep -Fq 'swayimg.text.size = 11' "$swayimg" || fail 'Swayimg text size does not match Cantarell 11'

printf 'dinx_theme_contract palette=true templates=true typography=true states=true gtk=true qt=true labwc=true swayimg=true greeter=true grub=true calamares=true\n'
