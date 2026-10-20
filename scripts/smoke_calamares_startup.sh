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
command -v calamares >/dev/null 2>&1 || fail 'calamares is not installed'
command -v timeout >/dev/null 2>&1 || fail 'timeout is not installed'
command -v xvfb-run >/dev/null 2>&1 || fail 'xvfb-run is not installed'

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mkdir -p "$work_dir/home" "$work_dir/cache"

set +e
HOME="$work_dir/home" \
  XDG_CACHE_HOME="$work_dir/cache" \
  timeout --kill-after=5s "${timeout_seconds}s" \
  xvfb-run -a calamares --debug --config "$config_dir" \
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
