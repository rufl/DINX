#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
theme_sync="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"
seed_palette="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
for tool in dbus-run-session dconf jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'smoke_dinx_theme_sync: missing tool: %s\n' "$tool" >&2; exit 1; }
done
[[ -x "$theme_sync" && -r "$seed_palette" ]] || {
  printf '%s\n' 'smoke_dinx_theme_sync: required session theme inputs are missing' >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM
home=$tmp/home
config=$tmp/config
profile=$tmp/dconf-profile
mkdir -p "$home" "$config/dinx" "$config/gtk-3.0" "$config/gtk-4.0" "$config/qt6ct/colors"
printf 'user-db:user\n' >"$profile"
cp "$seed_palette" "$config/qt6ct/colors/DINX.conf"
for version in 3.0 4.0; do
  printf '[Settings]\ngtk-icon-theme-name=Papirus\ngtk-application-prefer-dark-theme=0\n' >"$config/gtk-$version/settings.ini"
done
printf '[Appearance]\ncustom_palette=false\nicon_theme=Papirus\nstyle=Fusion\n' >"$config/qt6ct/qt6ct.conf"
cat >"$config/dinx/appearance.json" <<'JSON'
{"version":1,"theme":"DINX","variant":"dark","corners":"rounded"}
JSON

env HOME="$home" XDG_CONFIG_HOME="$config" DCONF_PROFILE="$profile" \
  dbus-run-session -- bash -c '
    set -euo pipefail
    sync=$1 config=$2
    ini_value() { awk -F= -v k="$2" '\''$1 == k {v=$2} END {print v}'\'' "$1"; }
    run_sync() { "$sync" >/dev/null; }
    key=/org/gnome/desktop/interface/color-scheme

    run_sync
    [[ $(dconf read "$key") == "'\''prefer-dark'\''" ]]
    for v in 3.0 4.0; do
      settings="$config/gtk-$v/settings.ini"
      [[ $(ini_value "$settings" gtk-theme-name) == DINX ]]
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 1 ]]
      [[ $(ini_value "$settings" gtk-icon-theme-name) == Papirus ]]
    done
    [[ $(ini_value "$config/qt6ct/qt6ct.conf" custom_palette) == true ]]

    jq '\''.variant="light" | .theme="Jasper" | .corners="square"'\'' "$config/dinx/appearance.json" >"$config/dinx/appearance.json.tmp"
    mv "$config/dinx/appearance.json.tmp" "$config/dinx/appearance.json"
    run_sync
    [[ $(dconf read "$key") == "'\''prefer-light'\''" ]]
    for v in 3.0 4.0; do
      settings="$config/gtk-$v/settings.ini"
      [[ $(ini_value "$settings" gtk-theme-name) == Jasper-Square-Light ]]
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 0 ]]
      [[ $(ini_value "$settings" gtk-icon-theme-name) == Papirus ]]
    done
    [[ $(ini_value "$config/qt6ct/qt6ct.conf" custom_palette) == false ]]

    jq '\''.variant="invalid" | .theme="Bogus" | .corners="diagonal"'\'' "$config/dinx/appearance.json" >"$config/dinx/appearance.json.tmp"
    mv "$config/dinx/appearance.json.tmp" "$config/dinx/appearance.json"
    run_sync
    [[ $(dconf read "$key") == "'\''prefer-dark'\''" ]]
    [[ $(ini_value "$config/gtk-3.0/settings.ini" gtk-theme-name) == DINX ]]
    [[ $(ini_value "$config/qt6ct/qt6ct.conf" custom_palette) == true ]]
  ' smoke_dinx_theme_sync "$theme_sync" "$config"

printf 'dinx_theme_sync_smoke first_run_dark=true appearance_light=true dconf=true gtk3=true gtk4=true qt6=true app_preferences_preserved=true invalid_values_default_dark=true\n'
