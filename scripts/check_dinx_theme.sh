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
swayimg="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/swayimg/init.lua"
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

for path in "$profile" "$palette" "$profile_shell" "$pearl_greeter" "$pearl_pkg" \
  "$grub" "$calamares" "$calamares_branding" "$qt" "$swayimg" \
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
grep -Fqx '    - noto-fonts' "$profile" || fail 'profile does not install Noto fonts'
grep -Fq 'DINX_COLOR_SCHEME="${DINX_COLOR_SCHEME:-dark}"' "$profile_shell" || fail 'DINX color scheme environment contract is missing'
grep -Fq 'color_scheme_path=~/.config/qt6ct/colors/DINX.conf' "$qt" || fail 'Qt6ct does not consume DINX colors'
grep -Fq 'general="Noto Sans,10' "$qt" || fail 'Qt6ct GUI font does not match Noto Sans 10'
grep -Fq '"theme": "gtk"' "$pearl_greeter" || fail 'Pearl Greeter does not use the GTK theme bridge'
grep -Fq '"gtk_theme": "DINX"' "$pearl_greeter" || fail 'Pearl Greeter does not use the DINX GTK theme'
grep -Fq '"wallpaper_color": "#0b0d12"' "$pearl_greeter" || fail 'Pearl Greeter surface color is missing'
grep -Fq '"font_size": 16' "$pearl_greeter" || fail 'Pearl Greeter font size is missing'
grep -Fq '"force_session": "wayland:dinx-aqueous-pearl.desktop"' "$pearl_greeter" \
  || fail 'Pearl Greeter does not force the DINX Aqueous/Pearl session'
grep -Fq '"allow_uwsm": false' "$pearl_greeter" || fail 'Pearl Greeter UWSM integration is not disabled'
grep -Fq '"x11": false' "$pearl_greeter" || fail 'Pearl Greeter X11 integration is not disabled'
if grep -Eiq 'systemd|systemctl' "$pearl_greeter"; then
  fail 'Pearl Greeter configuration contains a systemd integration'
fi
grep -Fq 'build-greeter' "$pearl_pkg" || fail 'Pearl Greeter is not built by the package'
grep -Fq 'pearl-greeter-host' "$pearl_pkg" || fail 'Pearl Greeter host is not packaged'
grep -Fq 'rm -rf "$pkgdir/usr/lib/systemd" "$pkgdir/usr/share/uwsm"' "$pearl_pkg" \
  || fail 'Pearl upstream lifecycle payloads are not removed'
for gtk_settings in "$gtk3_settings" "$gtk4_settings"; do
  grep -Fq 'gtk-theme-name=DINX' "$gtk_settings" || fail "GTK settings omit DINX theme: $gtk_settings"
  grep -Fq 'gtk-font-name=Noto Sans 10' "$gtk_settings" || fail "GTK settings omit Noto Sans 10: $gtk_settings"
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
printf 'dinx_theme_contract palette=true static=true typography=true states=true gtk=true qt=true swayimg=true pearl_greeter=true grub=true calamares=true\n'
