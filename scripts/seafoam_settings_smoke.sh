#!/usr/bin/env bash
set -euo pipefail

bin=${SEAFOAM_SETTINGS_BIN:-/usr/bin/seafoam-settings}
[[ -x "$bin" ]] || { printf 'seafoam_settings_smoke: missing executable: %s\n' "$bin" >&2; exit 1; }

output=$(mktemp)
trap 'rm -f "$output"' EXIT
xvfb-run -a "$bin" --smoke 2>&1 | tee "$output"
grep -Fqx 'seafoam_settings_smoke surface=true' "$output"
printf 'seafoam_settings_smoke_contract surface=true\n'
