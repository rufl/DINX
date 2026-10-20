#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config_dir="$root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares"
timeout_seconds=${DINX_CALAMARES_STARTUP_TIMEOUT:-15}

fail() {
  printf 'calamares_startup_smoke: %s\n' "$*" >&2
  exit 1
}

[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail 'DINX_CALAMARES_STARTUP_TIMEOUT must be a positive integer'
[[ -r "$config_dir/settings.conf" ]] || fail "Calamares settings are missing: $config_dir/settings.conf"
branding_dir="$config_dir/branding/dinx"
[[ -r "$branding_dir/branding.desc" ]] ||
  fail "Calamares branding descriptor is missing: $branding_dir/branding.desc"
command -v calamares >/dev/null 2>&1 || fail 'calamares is not installed'
command -v timeout >/dev/null 2>&1 || fail 'timeout is not installed'
command -v xvfb-run >/dev/null 2>&1 || fail 'xvfb-run is not installed'

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
qml_dir=$(find /usr -type d -path '*/calamares/qml' -print -quit 2>/dev/null)
[[ -n "$qml_dir" ]] || fail 'Calamares QML directory is not installed'
app_data="$work_dir/appdata"
mkdir -p "$work_dir/home" "$work_dir/cache" "$app_data"
ln -s "$config_dir/settings.conf" "$app_data/settings.conf"
ln -s "$config_dir/branding" "$app_data/branding"
ln -s "$config_dir/modules" "$app_data/modules"
ln -s "$qml_dir" "$app_data/qml"

set +e
  timeout --kill-after=5s "${timeout_seconds}s" \
xvfb-run -a calamares --debug --config "$app_data" \
  >"$work_dir/calamares.log" 2>&1
status=$?
set -e
cat "$work_dir/calamares.log"

case "$status" in
  0|124|137|143) ;;
  *) fail "Calamares startup exited before the bounded smoke completed: status $status" ;;
esac

grep -Eiq 'calamares' "$work_dir/calamares.log" || fail 'Calamares produced no startup log output'
for pattern in \
  'failed to load.*module' \
  'could not find.*settings\.conf' \
  'unknown module' \
  'no module named'; do
  if grep -Eiq "$pattern" "$work_dir/calamares.log"; then
    fail "Calamares startup reported a configuration/module failure: $pattern"
  fi
done

printf 'calamares_startup_smoke launched=true config=true module_errors=false timeout_seconds=%s\n' "$timeout_seconds"
