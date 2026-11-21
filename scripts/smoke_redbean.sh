#!/usr/bin/env bash
set -euo pipefail

redbean_bin=${1:-redbean}
startup_seconds=${REDBEAN_SMOKE_STARTUP_SECONDS:-3}
log_path=${REDBEAN_SMOKE_LOG:-${TMPDIR:-/tmp}/redbean-smoke.$$.log}

fail() {
  printf 'smoke_redbean: %s\n' "$*" >&2
  if [[ -s "$log_path" ]]; then
    cat "$log_path" >&2
  fi
  exit 1
}

[[ "$startup_seconds" =~ ^[1-9][0-9]*$ ]] || fail 'REDBEAN_SMOKE_STARTUP_SECONDS must be a positive integer'
command -v "$redbean_bin" >/dev/null 2>&1 || fail "redbean binary not found: $redbean_bin"
[[ -n "${WAYLAND_DISPLAY:-}" ]] || fail 'WAYLAND_DISPLAY is not set'
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || fail 'XDG_RUNTIME_DIR is not set'
[[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] || fail "Wayland socket is missing: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"

redbean_pid=
cleanup() {
  if [[ -n "$redbean_pid" ]] && kill -0 "$redbean_pid" 2>/dev/null; then
    kill -TERM "$redbean_pid" 2>/dev/null || true
    wait "$redbean_pid" 2>/dev/null || true
  fi
  rm -f -- "$log_path"
}
trap cleanup EXIT

"$redbean_bin" >"$log_path" 2>&1 &
redbean_pid=$!
for ((elapsed = 0; elapsed < startup_seconds; elapsed++)); do
  if ! kill -0 "$redbean_pid" 2>/dev/null; then
    fail "Redbean exited before the runtime smoke window"
  fi
  sleep 1
done

printf 'redbean_runtime_smoke started=true wayland=true pid=%s startup_seconds=%s\n' \
  "$redbean_pid" "$startup_seconds"
