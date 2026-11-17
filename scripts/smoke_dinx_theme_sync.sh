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
profile="$tmp/dconf-profile"
mkdir -p "$home" "$config_home/gtk-3.0" "$config_home/gtk-4.0" \
  "$config_home/qt6ct/colors" "$config_home/dconf"
printf 'user-db:user\n' >"$profile"
cp "$seed_palette" "$config_home/qt6ct/colors/DINX.conf"
[[ -z "$(find "$config_home" \( -name 'preferences.json' -o -name 'last-good.json' \) -print -quit)" ]]
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

env HOME="$home" XDG_CONFIG_HOME="$config_home" DCONF_PROFILE="$profile" \
  dbus-run-session -- bash -c '
    set -euo pipefail
    theme_sync=$1
    config_home=$2
    tmp=$3
    color_scheme_key=/org/gnome/desktop/interface/color-scheme

    ini_value() {
      awk -F= -v key="$2" '\''$1 == key { value = $2; found = 1 } END { if (found) print value }'\'' "$1"
    }
    run_sync() {
      "$theme_sync" >"$tmp/stdout" 2>"$tmp/stderr"
    }

    # No saved theme selection exists, yet the fixed dark appearance is applied.
    run_sync
    [[ $(dconf read "$color_scheme_key") == "'\''prefer-dark'\''" ]]
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
    grep -Fqx '\''general="Noto Sans,10"'\'' "$qt_config"
    grep -Fq "gtk_theme=DINX prefer_dark=1" "$tmp/stdout"
    [[ -z "$(find "$config_home" -name "*.tmp.*" -print -quit)" ]]

    # Idempotent: a second run changes nothing in the toolkit settings.
    for settings_dir in gtk-3.0 gtk-4.0 qt6ct; do
      cp -a "$config_home/$settings_dir" "$tmp/snapshot-$settings_dir"
    done
    run_sync
    for settings_dir in gtk-3.0 gtk-4.0 qt6ct; do
      diff -r "$tmp/snapshot-$settings_dir" "$config_home/$settings_dir"
    done

    # A user-managed symlink is never followed or replaced.
    symlink_target="$tmp/user-gtk-settings.ini"
    printf '"'"'[Settings]\n'"'"' >"$symlink_target"
    printf '"'"'gtk-theme-name=UserChosen\n'"'"' >>"$symlink_target"
    rm -f "$config_home/gtk-3.0/settings.ini"
    ln -s "$symlink_target" "$config_home/gtk-3.0/settings.ini"
    run_sync
    [[ -L "$config_home/gtk-3.0/settings.ini" ]]
    grep -Fq "gtk-theme-name=UserChosen" "$symlink_target"
    grep -Fq "preserving user-managed symlink" "$tmp/stderr"
    [[ $(ini_value "$config_home/gtk-4.0/settings.ini" gtk-theme-name) == DINX ]]

    # A fresh account with no config tree is provisioned from scratch.
    fresh_config="$tmp/fresh-config"
    XDG_CONFIG_HOME="$fresh_config"
    export XDG_CONFIG_HOME
    run_sync
    for gtk_version in 3.0 4.0; do
      settings="$fresh_config/gtk-$gtk_version/settings.ini"
      [[ $(ini_value "$settings" gtk-theme-name) == DINX ]]
      [[ $(ini_value "$settings" gtk-application-prefer-dark-theme) == 1 ]]
    done
    [[ $(ini_value "$fresh_config/qt6ct/qt6ct.conf" custom_palette) == true ]]

    # With no config directory at all the synchronizer still succeeds.
    env -u HOME -u XDG_CONFIG_HOME "$theme_sync" >"$tmp/empty-stdout" 2>"$tmp/empty-stderr"
    grep -Fq "no config directory" "$tmp/empty-stderr"
    [[ ! -s "$tmp/empty-stdout" ]]
  ' smoke_dinx_theme_sync "$theme_sync" "$config_home" "$tmp"

printf 'dinx_theme_sync_smoke no_input=true fixed_dark=true dconf_dark=true gtk3=true gtk4=true qt6=true papirus_default=true icon_settings_preserved=true idempotent=true symlink_guard=true fresh_home=true empty_home=true\n'
