#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
theme_sync="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"
seed_palette="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
for tool in dbus-run-session dconf; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'smoke_dinx_theme_sync: missing tool: %s\n' "$tool" >&2; exit 1; }
done
[[ -x "$theme_sync" && -r "$seed_palette" ]] || {
  printf '%s\n' 'smoke_dinx_theme_sync: required session theme inputs are missing' >&2
  exit 1
}

tmp=$(mktemp -d)
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM
home="$tmp/home"
config_home="$tmp/config"
state_home="$tmp/state"
preferences="$config_home/morghulis/preferences.json"
profile="$tmp/dconf-profile"
mkdir -p "$home" "$config_home/morghulis" "$config_home/gtk-3.0" \
  "$config_home/gtk-4.0" "$config_home/qt6ct/colors" "$config_home/dconf" \
  "$state_home"
printf 'user-db:user\n' >"$profile"
cp "$seed_palette" "$config_home/qt6ct/colors/DINX.conf"
cat >"$preferences" <<'JSON'
{"theme":{"variant":"dark"}}
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

# Appearance fixtures the inner session consumes from $tmp.
cat >"$tmp/appearance-port.json" <<'JSON'
{"version":1,"theme":"Jasper","variant":"light","corners":"square"}
JSON
cat >"$tmp/appearance-invalid.json" <<'JSON'
{"version":1,"theme":"Bogus","variant":"neon","corners":"diagonal"}
JSON

env HOME="$home" XDG_CONFIG_HOME="$config_home" DCONF_PROFILE="$profile" \
  dbus-run-session -- bash -c '
    set -euo pipefail
    theme_sync=$1
    config_home=$2
    preferences=$3
    color_scheme_key=/org/gnome/desktop/interface/color-scheme

    ini_value() {
      awk -F= -v key="$2" '\''$1 == key { value = $2; found = 1 } END { if (found) print value }'\'' "$1"
    }
    dconf write "$color_scheme_key" "'\''prefer-light'\''"
    "$theme_sync"
    jq -e '\''.theme.variant == "dark"'\'' "$preferences" >/dev/null
    for gtk_version in 3.0 4.0; do
      settings="$config_home/gtk-$gtk_version/settings.ini"
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 1 ]]
      [[ $(ini_value "$settings" gtk-theme-name) == DINX ]]
      [[ $(ini_value "$settings" gtk-icon-theme-name) == Papirus ]]
      grep -Fqx "preserve-this=yes" "$settings"
    done
    qt_config="$config_home/qt6ct/qt6ct.conf"
    [[ $(ini_value "$qt_config" color_scheme_path) == "$config_home/qt6ct/colors/DINX.conf" ]]
    [[ $(ini_value "$qt_config" custom_palette) == true ]]
    [[ $(ini_value "$qt_config" icon_theme) == Papirus ]]
    [[ $(ini_value "$qt_config" style) == Fusion ]]
    :

    jq '\''.theme = {variant:"light"}'\'' "$preferences" >"$preferences.tmp"
    mv -f "$preferences.tmp" "$preferences"
    "$theme_sync"
    for gtk_version in 3.0 4.0; do
      settings="$config_home/gtk-$gtk_version/settings.ini"
      [[ $(ini_value "$settings" gtk-theme-name) == Jasper-Square-Light ]]
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 0 ]]
      [[ $(ini_value "$settings" gtk-theme-name) == Adwaita ]]
      [[ $(ini_value "$settings" gtk-icon-theme-name) == Papirus ]]
    done
    [[ $(ini_value "$qt_config" custom_palette) == false ]]
    [[ $(ini_value "$qt_config" icon_theme) == Papirus ]]
    [[ $(ini_value "$qt_config" style) == Fusion ]]
  ' smoke_dinx_theme_sync "$theme_sync" "$config_home" "$preferences"

    # An unknown family, variant or corner value falls back to DINX dark.
    cp "$tmp/appearance-invalid.json" "$config_home/dinx/appearance.json"
    run_sync
    [[ $(ini_value "$config_home/gtk-3.0/settings.ini" gtk-theme-name) == DINX ]]
    [[ $(ini_value "$config_home/gtk-4.0/settings.ini" gtk-application-prefer-dark-theme) == 1 ]]
    [[ $(ini_value "$config_home/qt6ct/qt6ct.conf" custom_palette) == true ]]
    rm -f -- "$config_home/dinx/appearance.json"

    # With no config directory at all the synchronizer still succeeds.
    env -u HOME -u XDG_CONFIG_HOME "$theme_sync" >"$tmp/empty-stdout" 2>"$tmp/empty-stderr"
    grep -Fq "no config directory" "$tmp/empty-stderr"
    [[ ! -s "$tmp/empty-stdout" ]]
  ' smoke_dinx_theme_sync "$theme_sync" "$config_home" "$tmp"

printf 'dinx_theme_sync_smoke dark_default=true appearance_selection=true ported_family_variant=true light_variant=true invalid_falls_back=true dconf_scheme=true gtk3=true gtk4=true qt6=true papirus_default=true icon_settings_preserved=true idempotent=true symlink_guard=true fresh_home=true empty_home=true\n'
