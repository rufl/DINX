#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
theme_sync="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"
pearl_shell="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-pearl-shell"
seed_palette="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
for tool in dbus-run-session dconf jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'smoke_dinx_theme_sync: missing tool: %s\n' "$tool" >&2; exit 1; }
done
[[ -x "$theme_sync" && -x "$pearl_shell" && -r "$seed_palette" ]] || {
  printf '%s\n' 'smoke_dinx_theme_sync: required session theme inputs are missing' >&2
  exit 1
}

tmp=$(mktemp -d)
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM
home="$tmp/home"
config_home="$tmp/config"
state_home="$tmp/state"
fakebin="$tmp/bin"
preferences="$config_home/pearl/preferences.json"
profile="$tmp/dconf-profile"
mkdir -p "$home" "$config_home/pearl" "$config_home/gtk-3.0" \
  "$config_home/gtk-4.0" "$config_home/qt6ct/colors" "$config_home/dconf" \
  "$state_home" "$fakebin"
printf 'user-db:user\n' >"$profile"
cp "$seed_palette" "$config_home/qt6ct/colors/DINX.conf"
cat >"$preferences" <<'JSON'
{"theme":{"mode":"static","variant":"light","gtk_name":""}}
JSON
for gtk_version in 3.0 4.0; do
  cat >"$config_home/gtk-$gtk_version/settings.ini" <<'INI'
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Papirus
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=0
[Unrelated]
preserve-this=yes
INI
done
cat >"$config_home/qt6ct/qt6ct.conf" <<'INI'
[Appearance]
color_scheme_path=~/.config/qt6ct/colors/Light.conf
custom_palette=false
icon_theme=Papirus
style=Fusion
[Fonts]
general="Noto Sans,10"
INI
cat >"$fakebin/pearl" <<'SH'
#!/bin/sh
exit 0
SH
cat >"$tmp/wizard" <<'SH'
#!/bin/sh
printf 'called\n' >>"$DINX_WIZARD_CALLS"
printf 'off bottom material dark rounded\n'
SH
chmod +x "$fakebin/pearl" "$tmp/wizard"

env HOME="$home" XDG_CONFIG_HOME="$config_home" XDG_STATE_HOME="$state_home" \
  DCONF_PROFILE="$profile" dbus-run-session -- bash -c '
    set -euo pipefail
    theme_sync=$1
    pearl_shell=$2
    fakebin=$3
    wizard=$4
    config_home=$5
    preferences=$6
    calls=$7
    export PATH="$fakebin:$PATH"
    export DINX_THEME_SYNC_HELPER="$theme_sync"
    export DINX_FIRST_RUN_WIZARD="$wizard"
    export DINX_WIZARD_CALLS="$calls"
    color_scheme_key=/org/gnome/desktop/interface/color-scheme

    ini_value() {
      awk -F= -v key="$2" '\''$1 == key { value = $2; found = 1 } END { if (found) print value }'\'' "$1"
    }
    dconf write "$color_scheme_key" "'\''prefer-light'\''"
    "$pearl_shell"
    jq -e '\''.theme.variant == "dark" and .theme.mode == "static"'\'' "$preferences" >/dev/null
    for gtk_version in 3.0 4.0; do
      settings="$config_home/gtk-$gtk_version/settings.ini"
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 1 ]]
      [[ $(ini_value "$settings" gtk-theme-name) == Adwaita ]]
      [[ $(ini_value "$settings" gtk-icon-theme-name) == Papirus ]]
      grep -Fqx "preserve-this=yes" "$settings"
    done
    qt_config="$config_home/qt6ct/qt6ct.conf"
    [[ $(ini_value "$qt_config" color_scheme_path) == "$config_home/qt6ct/colors/DINX.conf" ]]
    [[ $(ini_value "$qt_config" custom_palette) == true ]]
    [[ $(ini_value "$qt_config" icon_theme) == Papirus ]]
    [[ $(ini_value "$qt_config" style) == Fusion ]]
    [[ $(wc -l <"$calls") == 1 ]]

    jq '\''.theme = {mode:"gtk",variant:"light",gtk_name:"DINX"}'\'' "$preferences" >"$preferences.tmp"
    mv -f "$preferences.tmp" "$preferences"
    "$pearl_shell"
    for gtk_version in 3.0 4.0; do
      settings="$config_home/gtk-$gtk_version/settings.ini"
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 0 ]]
      [[ $(ini_value "$settings" gtk-theme-name) == DINX ]]
      [[ $(ini_value "$settings" gtk-icon-theme-name) == Papirus ]]
    done
    [[ $(ini_value "$qt_config" custom_palette) == false ]]
    [[ $(ini_value "$qt_config" icon_theme) == Papirus ]]
    [[ $(ini_value "$qt_config" style) == Fusion ]]
    [[ $(wc -l <"$calls") == 1 ]]

    jq '\''.theme = {mode:"package",variant:"dark",gtk_name:"Skeuos-Blue-Dark-Square",package_id:"dinx.skeuos-square"}'\'' "$preferences" >"$preferences.tmp"
    mv -f "$preferences.tmp" "$preferences"
    "$pearl_shell"
    for gtk_version in 3.0 4.0; do
      settings="$config_home/gtk-$gtk_version/settings.ini"
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 1 ]]
      [[ $(ini_value "$settings" gtk-theme-name) == Skeuos-Blue-Dark-Square ]]
    done
    [[ $(ini_value "$qt_config" color_scheme_path) == "$config_home/qt6ct/colors/pearl-material.conf" ]]
    [[ $(ini_value "$qt_config" custom_palette) == true ]]
    [[ $(readlink "$config_home/deetty/themes/pearl-material") == ../../ghostty/themes/pearl-material ]]
    grep -Fqx "theme = pearl-material" "$config_home/deetty/config"
    [[ $(wc -l <"$calls") == 1 ]]
  ' smoke_dinx_theme_sync "$theme_sync" "$pearl_shell" "$fakebin" \
  "$tmp/wizard" "$config_home" "$preferences" "$tmp/wizard-calls"

printf 'dinx_theme_sync_smoke material_dark=true gtk3=true gtk4=true qt6=true papirus_default=true icon_settings_preserved=true light_transition=true gtk_theme_choice=true package_theme=true qt_generated_palette=true deetty_bridge=true preserves_unrelated_settings=true\n'
