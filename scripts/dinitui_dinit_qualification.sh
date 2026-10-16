#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'dinitui_dinit_qualification: %s\n' "$*" >&2
  exit 1
}

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
dinit_bin=${DINIT_BIN:-dinit}
dinitctl_bin=${DINITCTL_BIN:-dinitctl}
dinitui_bin=${DINITUI_BIN:-$root/distro/packages/dinitui/zig-out/bin/dinitui}

dinit_bin=$(command -v "$dinit_bin") || fail "Dinit daemon not found: ${DINIT_BIN:-dinit}"
dinitctl_bin=$(command -v "$dinitctl_bin") || fail "dinitctl not found: ${DINITCTL_BIN:-dinitctl}"
command -v xvfb-run >/dev/null 2>&1 || fail 'xvfb-run is not installed'
[[ -x "$dinitui_bin" ]] || fail "DinitUI binary not found: $dinitui_bin"

tmp=$(mktemp -d)
cleanup() {
  if [[ -n "${daemon_pid:-}" ]]; then
    kill "$daemon_pid" 2>/dev/null || true
    wait "$daemon_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT
home="$tmp/home"
run="$tmp/run"
mkdir -p "$home/.config/dinit.d" "$run" "$tmp/bin"

cat >"$tmp/fixture-service" <<'EOF'
#!/bin/sh
set -eu
while :; do sleep 1; done
EOF
chmod +x "$tmp/fixture-service"
printf 'type = process\ncommand = %s\nlogfile = %s\n' "$tmp/fixture-service" "$tmp/fixture.log" >"$home/.config/dinit.d/fixture"

cat >"$tmp/bin/dinitctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args=()
for arg in "$@"; do
  case "$arg" in
    --system|--user) ;;
    *) args+=("$arg") ;;
  esac
done
exec "$DINIT_REAL" --user --socket-path "$DINIT_SOCKET" "${args[@]}"
EOF
chmod +x "$tmp/bin/dinitctl"

XDG_RUNTIME_DIR="$run" HOME="$home" "$dinit_bin" \
  --user \
  --socket-path "$run/dinitctl" \
  --services-dir "$home/.config/dinit.d" \
  --service fixture \
  >"$tmp/dinit.log" 2>&1 &
daemon_pid=$!
for _ in $(seq 1 100); do
  [[ -S "$run/dinitctl" ]] && break
  sleep 0.1
done
[[ -S "$run/dinitctl" ]] || { cat "$tmp/dinit.log" >&2; fail 'Dinit socket did not appear'; }

ctl=("$dinitctl_bin" --user --socket-path "$run/dinitctl")
list_output=$("${ctl[@]}" list)
grep -Fq 'fixture' <<<"$list_output" || fail 'real dinitctl list omitted fixture'
status_output=$("${ctl[@]}" status fixture)
grep -Fq 'STARTED' <<<"$status_output" || fail 'real dinitctl status did not report STARTED'

ui_output=$(
  PATH="$tmp/bin:$PATH" \
    DINIT_REAL="$dinitctl_bin" \
    DINIT_SOCKET="$run/dinitctl" \
    XDG_RUNTIME_DIR="$run" \
    HOME="$home" \
    GDK_BACKEND=x11 \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_CACHE_HOME="$home/.cache" \
    xvfb-run -a "$dinitui_bin" --smoke 2>&1
)
printf '%s\n' "$ui_output"
grep -Fq 'dinitui_smoke surface=true services=1' <<<"$ui_output" || fail 'GTK smoke did not discover the real Dinit service'
"${ctl[@]}" stop fixture >/dev/null
printf 'dinitui_dinit_runtime daemon=true dinitctl=list-status-stop gtk_smoke=service-discovered\n'
