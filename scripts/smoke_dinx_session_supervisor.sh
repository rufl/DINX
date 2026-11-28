#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
supervisor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-session-supervisor"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fakebin="$tmp/bin"
libexec="$tmp/libexec"
state="$tmp/pids"
mkdir -p "$fakebin" "$libexec" "$state"

# Required helpers: KWM, Shikane, the PolicyKit agent and the Morghulis shell
# are resolved through PATH, the idle wrapper through DINX_SESSION_LIBEXEC. The
# first-run glue is a short-lived foreground helper that must complete before
# the shell starts, so it records a marker and exits.
make_helper() {
  name=$1
  dir=$2
  cat >"$dir/$name" <<EOF
#!/bin/sh
printf '%s\n' "\$\$" >"$state/$name.pid"
while :; do /usr/bin/sleep 1; done
EOF
  chmod +x "$dir/$name"
}
make_helper kwm "$fakebin"
make_helper shikane "$fakebin"
make_helper lxqt-policykit-agent "$fakebin"
make_helper morghulis "$fakebin"
make_helper dinx-idle "$libexec"
cat >"$libexec/dinx-desktop-first-run" <<EOF
#!/bin/sh
: >"$state/first-run-ran"
EOF
chmod +x "$libexec/dinx-desktop-first-run"

export DINX_SESSION_SKIP_WAYLAND_CHECK=1
export DINX_SESSION_SKIP_DBUS_CHECK=1
export DINX_SESSION_LIBEXEC="$libexec"
export PATH="$fakebin:$PATH"
export XDG_STATE_HOME="$tmp/state-home"

wait_for_status() {
  expected=$1
  for _ in $(seq 1 300); do
    if [ -f "$XDG_STATE_HOME/dinx/session.status" ] &&
      grep -Fqx "status=$expected" "$XDG_STATE_HOME/dinx/session.status"; then
      return 0
    fi
    /usr/bin/sleep 0.01
  done
  return 1
}

helper_stopped() {
  helper=$1
  pid=$(cat "$state/$helper.pid")
  for _ in $(seq 1 300); do
    kill -0 "$pid" 2>/dev/null || return 0
    /usr/bin/sleep 0.01
  done
  printf 'dinx_session_supervisor_smoke: helper still alive: %s\n' "$helper" >&2
  kill -KILL "$pid" 2>/dev/null || true
  return 1
}

if "$supervisor" retired-mode >/dev/null 2>&1; then
  printf 'dinx_session_supervisor_smoke: the supervisor accepted an unsupported session mode\n' >&2
  exit 1
fi
if "$supervisor" >/dev/null 2>&1; then
  printf 'dinx_session_supervisor_smoke: the supervisor started without a session mode\n' >&2
  exit 1
fi

"$supervisor" river >/dev/null 2>&1 &
supervisor_pid=$!
wait_for_status ready
grep -Fqx 'mode=river' "$XDG_STATE_HOME/dinx/session.status" || {
  printf 'dinx_session_supervisor_smoke: the supervisor did not record its river mode\n' >&2
  exit 1
}
for helper in kwm shikane lxqt-policykit-agent dinx-idle morghulis; do
  [ -s "$state/$helper.pid" ] || {
    printf 'dinx_session_supervisor_smoke: required helper never started: %s\n' "$helper" >&2
    exit 1
  }
done
if [ ! -e "$state/first-run-ran" ]; then
  printf 'dinx_session_supervisor_smoke: the first-run helper never completed before the shell started\n' >&2
  exit 1
fi
if [ "$(stat -c %Y "$state/first-run-ran")" -gt "$(stat -c %Y "$state/morghulis.pid")" ]; then
  printf 'dinx_session_supervisor_smoke: Morghulis started before first-run finished\n' >&2
  exit 1
fi
kill -TERM "$(cat "$state/dinx-idle.pid")"
wait_for_status failed
wait "$supervisor_pid" || true
grep -Fq 'reason=helper-idle-exited' "$XDG_STATE_HOME/dinx/session.log" || {
  printf 'dinx_session_supervisor_smoke: helper failure reason was not logged\n' >&2
  exit 1
}
grep -Eq 'helper=idle exited status=[0-9]+' "$XDG_STATE_HOME/dinx/session.log" || {
  printf 'dinx_session_supervisor_smoke: helper exit status was not logged\n' >&2
  exit 1
}
for helper in kwm shikane lxqt-policykit-agent morghulis; do
  helper_stopped "$helper" || exit 1
done

rm -rf "$XDG_STATE_HOME" "$state"
mkdir -p "$state"
"$supervisor" river >/dev/null 2>&1 &
supervisor_pid=$!
wait_for_status ready
kill -TERM "$supervisor_pid"
wait "$supervisor_pid" || true
for helper in kwm shikane lxqt-policykit-agent dinx-idle morghulis; do
  helper_stopped "$helper" || exit 1
done

rm -rf "$XDG_STATE_HOME" "$state"
mkdir -p "$state"
/usr/bin/sleep 30 &
compositor_pid=$!
DINX_SESSION_COMPOSITOR_PID="$compositor_pid" "$supervisor" river >/dev/null 2>&1 &
supervisor_pid=$!
wait_for_status ready
kill -TERM "$supervisor_pid"
wait "$supervisor_pid" || true

parent_alive=false
for _ in $(seq 1 300); do
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
for helper in kwm shikane lxqt-policykit-agent dinx-idle morghulis; do
  helper_stopped "$helper" || exit 1
done

rm -rf "$XDG_STATE_HOME" "$state"
mkdir -p "$state"
/usr/bin/sleep 30 &
compositor_pid=$!
DINX_SESSION_COMPOSITOR_PID="$compositor_pid" "$supervisor" river >/dev/null 2>&1 &
supervisor_pid=$!
wait_for_status ready
kill -TERM "$compositor_pid"
wait_for_status exited
wait "$supervisor_pid" || true
for helper in kwm shikane lxqt-policykit-agent dinx-idle morghulis; do
  helper_stopped "$helper" || exit 1
done

printf 'dinx_session_supervisor_smoke river_ready=true required_helpers=kwm+shikane+policykit+idle+morghulis first_run=before_shell retired_mode_rejected=true helper_failure=true signal_cleanup=true compositor_parent_terminated=true compositor_exit_status=exited\n'
