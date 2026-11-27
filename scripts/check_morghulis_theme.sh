#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/profile.d/dinx.sh"
session="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-river-session"
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
first_run="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-desktop-first-run"
theme_sync="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-sync-session-theme"
qt="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/qt6ct.conf"
palette="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/skel/.config/qt6ct/colors/DINX.conf"
gtk3="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/gtk-3.0/settings.ini"
gtk4="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/gtk-4.0/settings.ini"
fail() { printf 'morghulis_theme_contract: %s\n' "$*" >&2; exit 1; }
for path in "$profile" "$session" "$supervisor" "$first_run" "$theme_sync" "$qt" "$palette" "$gtk3" "$gtk4"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done
for path in "$session" "$supervisor" "$first_run" "$theme_sync"; do
  [[ -x "$path" ]] || fail "not executable: ${path#$root/}"
  sh -n "$path" || fail "invalid shell syntax: ${path#$root/}"
done
# Morghulis NavBar matches XDG_CURRENT_DESKTOP literally against "river"; anything
# else silently disables its tag/mode/view modules, so pin the exact value here.
grep -Fqx 'export XDG_CURRENT_DESKTOP=river' "$session" \
  || fail 'session must export XDG_CURRENT_DESKTOP=river for the Morghulis river backend'
grep -Fqx 'export XDG_SESSION_DESKTOP=river' "$session" \
  || fail 'session identity is not river'
grep -Fq 'preferences="$config_home/morghulis/preferences.json"' "$theme_sync" || fail 'theme sync is not Morghulis-specific'
grep -Fq 'desktop-first-run-complete' "$first_run" || fail 'desktop first-run marker is missing'
grep -Fq '"$theme_sync"' "$first_run" || fail 'first-run result is not passed to theme sync'
grep -Fq 'first_run_helper=${DINX_FIRST_RUN_HELPER:-$libexec_dir/dinx-desktop-first-run}' "$supervisor" || fail 'session supervisor does not launch first-run setup'
grep -Fqx 'color_scheme_path=~/.config/qt6ct/colors/DINX.conf' "$qt" || fail 'Qt6ct does not select the DINX palette'
grep -Fq 'gtk-application-prefer-dark-theme=1' "$gtk3" || fail 'GTK3 defaults are not dark'
grep -Fq 'gtk-application-prefer-dark-theme=1' "$gtk4" || fail 'GTK4 defaults are not dark'
grep -Fq 'active_colors=#ffd7dde8, #ff11151d' "$palette" || fail 'DINX palette role order changed'
for retired in Aqueous Pearl pearl aqueous; do
  if grep -Fq "$retired" "$session" "$supervisor" "$first_run" "$theme_sync"; then
    fail "retired session identity remains in Morghulis theme files: $retired"
  fi
done
printf 'morghulis_theme_contract first_run=true theme_sync=true gtk_dark=true qt_palette=true retired_session_identities=false supervised=true\n'
