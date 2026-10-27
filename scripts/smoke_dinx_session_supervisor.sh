#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fakebin="$tmp/bin"
libexec="$tmp/libexec"
state="$tmp/state"
mkdir -p "$fakebin" "$libexec" "$state"

make_helper() {
  name=$1
  cat >"$fakebin/$name" <<EOF
#!/bin/sh
printf '%s\n' "\$\$" >"$state/$name.pid"
while :; do /usr/bin/sleep 1; done
EOF
  chmod +x "$fakebin/$name"
}
for helper in shikane lxqt-policykit-agent pearl; do
  make_helper "$helper"
done
cp "$fakebin/shikane" "$libexec/dinx-idle"

export DINX_SESSION_SKIP_WAYLAND_CHECK=1
export DINX_SESSION_SKIP_DBUS_CHECK=1
export DINX_SESSION_LIBEXEC="$libexec"
export PATH="$fakebin:$PATH"
export XDG_STATE_HOME="$tmp/state-home"

wait_for_status() {
  expected=$1
  for _ in $(seq 1 100); do
    if [ -f "$XDG_STATE_HOME/dinx/session.status" ] &&
      grep -Fqx "status=$expected" "$XDG_STATE_HOME/dinx/session.status"; then
      return 0
    fi
    /usr/bin/sleep 0.01
  done
  return 1
}

DINX_SESSION_COMPOSITOR_PID= "${supervisor}" aqueous >/dev/null 2>&1 &
supervisor_pid=$!
wait_for_status ready
kill -TERM "$(cat "$state/pearl.pid")"
wait_for_status failed
wait "$supervisor_pid" || true

rm -rf "$XDG_STATE_HOME"
DINX_SESSION_COMPOSITOR_PID= "${supervisor}" aqueous >/dev/null 2>&1 &
supervisor_pid=$!
wait_for_status ready
kill -TERM "$supervisor_pid"
wait "$supervisor_pid" || true

rm -rf "$XDG_STATE_HOME"
/usr/bin/sleep 30 &
compositor_pid=$!
DINX_SESSION_COMPOSITOR_PID="$compositor_pid" "${supervisor}" aqueous >/dev/null 2>&1 &
supervisor_pid=$!
wait_for_status ready
kill -TERM "$supervisor_pid"
wait "$supervisor_pid" || true

parent_alive=false
for _ in $(seq 1 100); do
  if ! kill -0 "$compositor_pid" 2>/dev/null; then
    break
  fi
  parent_state=$(ps -o stat= -p "$compositor_pid" 2>/dev/null | tr -d ' ')
  if [ -z "$parent_state" ] || [ "${parent_state#Z}" != "$parent_state" ]; then
    break
  fi
  parent_alive=true
  /usr/bin/sleep 0.01
done
if [ "$parent_alive" = true ]; then
  printf 'dinx_session_supervisor_smoke: supervisor did not terminate its compositor parent\n' >&2
  kill -KILL "$compositor_pid" 2>/dev/null || true
  exit 1
fi
wait "$compositor_pid" || true

printf 'dinx_session_supervisor_smoke aqueous_ready=true helper_failure=true signal_cleanup=true\n'
