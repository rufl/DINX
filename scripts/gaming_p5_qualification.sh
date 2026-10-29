#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'gaming_p5_qualification: %s\n' "$*" >&2
  exit 1
}

command -v gamescope >/dev/null 2>&1 || fail 'gamescope is not installed'
command -v timeout >/dev/null 2>&1 || fail 'timeout is not installed'
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
launcher="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-gaming"
[[ -x "$launcher" ]] || fail 'DINX gaming launcher is missing or not executable'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/gamescope" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$DINX_GAMESCOPE_ARGS"
if [ "${DINX_GAMESCOPE_HOLD:-0}" = 1 ]; then
  printf 'gamescope-started' > "$DINX_GAMESCOPE_HOLD_MARKER"
  trap 'exit 143' TERM INT
  sleep 5 &
  wait "$!"
  exit 0
fi
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
[ "$#" -gt 0 ] || exit 64
shift
exec "$@"
EOF


cat >"$tmp/bin/gamemoderun" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" > "$DINX_GAMEMODE_ARGS"
exec "$@"
EOF
cat >"$tmp/bin/steam" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" > "$DINX_STEAM_ARGS"
printf 'steam-fixture-started' > "$DINX_STEAM_MARKER"
printf 'steam-fixture-exited' >> "$DINX_STEAM_MARKER"
EOF
chmod +x "$tmp/bin/gamescope" "$tmp/bin/gamemoderun" "$tmp/bin/steam"
cat >"$tmp/bin/dinitui" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$1" >> "$DINX_DINITUI_ARGS"
case "$1" in
  --gaming-enter)
    [ "${DINX_DINITUI_FAIL_ENTER:-0}" = 0 ]
    ;;
  --gaming-leave)
    [ "${DINX_DINITUI_FAIL_LEAVE:-0}" = 0 ]
    ;;
  *)
    exit 64
    ;;
esac
EOF
chmod +x "$tmp/bin/dinitui"
mkdir -p "$tmp/missing-gamescope-bin" "$tmp/missing-steam-bin"
for fixture_bin in "$tmp/missing-gamescope-bin" "$tmp/missing-steam-bin"; do
  cat >"$fixture_bin/dinitui" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >> "$DINX_DINITUI_ARGS"
EOF
  chmod +x "$fixture_bin/dinitui"
done
cat >"$tmp/missing-steam-bin/gamescope" <<'EOF'
#!/bin/sh
printf 'unexpected-gamescope-start' >"$DINX_GAMESCOPE_MARKER"
exit 99
EOF
chmod +x "$tmp/missing-steam-bin/gamescope"

set +e
PATH="$tmp/missing-gamescope-bin" \
  DINX_DINITUI_ARGS="$tmp/missing-gamescope-dinitui" \
  "$launcher" >"$tmp/missing-gamescope.log" 2>&1
missing_gamescope_status=$?
set -e
[[ "$missing_gamescope_status" -eq 127 ]] || fail 'missing Gamescope did not fail before profile changes'
grep -Fq 'gamescope is not installed' "$tmp/missing-gamescope.log" || fail 'missing Gamescope guidance was not shown'
[[ ! -e "$tmp/missing-gamescope-dinitui" ]] || fail 'launcher changed the Dinit profile without Gamescope'
printf 'gaming_missing_package_fixture gamescope=fail_closed=true profile=unchanged=true\n'

set +e
PATH="$tmp/missing-steam-bin" \
  DINX_DINITUI_ARGS="$tmp/missing-steam-dinitui" \
  DINX_GAMESCOPE_MARKER="$tmp/missing-steam-gamescope" \
  "$launcher" >"$tmp/missing-steam.log" 2>&1
missing_steam_status=$?
set -e
[[ "$missing_steam_status" -eq 127 ]] || fail 'missing Steam did not fail before profile changes'
grep -Fq 'steam is not installed' "$tmp/missing-steam.log" || fail 'missing Steam guidance was not shown'
[[ ! -e "$tmp/missing-steam-dinitui" ]] || fail 'launcher changed the Dinit profile without Steam'
[[ ! -e "$tmp/missing-steam-gamescope" ]] || fail 'launcher started Gamescope without Steam'
printf 'gaming_missing_package_fixture steam=fail_closed=true profile=unchanged=true\n'

PATH="$tmp/bin:$PATH" \
  DINX_GAMEMODE=auto \
  DINX_DINITUI_ARGS="$tmp/dinitui-args" \
  DINX_DINITUI_FAIL_ENTER=0 \
  DINX_DINITUI_FAIL_LEAVE=0 \
  DINX_GAMESCOPE_ARGS="$tmp/gamescope-args" \
  DINX_GAMEMODE_ARGS="$tmp/gamemode-args" \
  DINX_STEAM_ARGS="$tmp/steam-args" \
  DINX_STEAM_MARKER="$tmp/steam-marker" \
  "$launcher"
grep -Fqx -- '--backend drm --steam --fullscreen -- steam -tenfoot' "$tmp/gamescope-args" || fail 'launcher Gamescope argv is incorrect'
test "$(wc -l < "$tmp/gamescope-args")" -eq 1 || fail 'launcher dispatched Gamescope more than once'
grep -Fqx -- 'gamescope --backend drm --steam --fullscreen -- steam -tenfoot' "$tmp/gamemode-args" || fail 'launcher did not dispatch through GameMode'
grep -Fqx -- '-tenfoot' "$tmp/steam-args" || fail 'launcher Steam argv is incorrect'
grep -Fqx 'steam-fixture-startedsteam-fixture-exited' "$tmp/steam-marker" || fail 'launcher did not return after Steam exit'
printf 'gaming_session_fixture launcher=start-exit gamescope_argv=true steam_argv=true\n'
grep -Fqx -- '--gaming-enter' "$tmp/dinitui-args" || fail 'launcher did not enter the Gaming profile'
grep -Fqx -- '--gaming-leave' "$tmp/dinitui-args" || fail 'launcher did not restore the previous profile'
test "$(wc -l < "$tmp/dinitui-args")" -eq 2 || fail 'launcher dispatched DinitUI more than once per transition'
printf 'gaming_profile_fixture enter=true leave=true\n'

set +e
PATH="$tmp/bin:$PATH" \
  DINX_DINITUI_ARGS="$tmp/entry-failure-dinitui" \
  DINX_DINITUI_FAIL_ENTER=1 \
  DINX_DINITUI_FAIL_LEAVE=0 \
  DINX_GAMESCOPE_ARGS="$tmp/entry-failure-gamescope" \
  DINX_GAMEMODE_ARGS="$tmp/entry-failure-gamemode" \
  DINX_STEAM_ARGS="$tmp/entry-failure-steam" \
  DINX_STEAM_MARKER="$tmp/entry-failure-steam-marker" \
  "$launcher" >"$tmp/entry-failure.log" 2>&1
entry_status=$?
set -e
[[ "$entry_status" -ne 0 ]] || fail 'launcher continued after Gaming profile entry failed'
[[ ! -e "$tmp/entry-failure-gamescope" ]] || fail 'launcher started Gamescope after Gaming profile entry failed'
grep -Fq 'failed to enter Gaming profile' "$tmp/entry-failure.log" || fail 'entry failure was not reported'
printf 'gaming_profile_failure entry=fail_closed=true gamescope=not_started=true\n'

set +e
PATH="$tmp/bin:$PATH" \
  DINX_DINITUI_ARGS="$tmp/leave-failure-dinitui" \
  DINX_DINITUI_FAIL_ENTER=0 \
  DINX_DINITUI_FAIL_LEAVE=1 \
  DINX_GAMESCOPE_ARGS="$tmp/leave-failure-gamescope" \
  DINX_GAMEMODE_ARGS="$tmp/leave-failure-gamemode" \
  DINX_STEAM_ARGS="$tmp/leave-failure-steam" \
  DINX_STEAM_MARKER="$tmp/leave-failure-steam-marker" \
  "$launcher" >"$tmp/leave-failure.log" 2>&1
leave_status=$?
set -e
[[ "$leave_status" -ne 0 ]] || fail 'launcher hid Gaming profile restoration failure'
grep -Fq -- '--gaming-enter' "$tmp/leave-failure-dinitui" || fail 'launcher did not enter Gaming profile before restoration test'
grep -Fq -- '--gaming-leave' "$tmp/leave-failure-dinitui" || fail 'launcher did not attempt Gaming profile restoration'
grep -Fq 'failed to restore the previous profile' "$tmp/leave-failure.log" || fail 'restoration failure was not reported'
printf 'gaming_profile_failure leave=reported=true nonzero=true\n'
set +e
PATH="$tmp/bin:$PATH" \
  DINX_GAMEMODE=off \
  DINX_GAMESCOPE_HOLD=1 \
  DINX_DINITUI_ARGS="$tmp/signal-dinitui" \
  DINX_DINITUI_FAIL_ENTER=0 \
  DINX_DINITUI_FAIL_LEAVE=0 \
  DINX_GAMESCOPE_ARGS="$tmp/signal-gamescope-args" \
  DINX_GAMESCOPE_HOLD_MARKER="$tmp/signal-gamescope-marker" \
  "$launcher" >"$tmp/signal.log" 2>&1 &
signal_launcher_pid=$!
for attempt in {1..20}; do
  [[ -f "$tmp/signal-gamescope-marker" ]] && break
  sleep 0.1
done
[[ -f "$tmp/signal-gamescope-marker" ]] || {
  kill -KILL "$signal_launcher_pid" 2>/dev/null || :
  wait "$signal_launcher_pid" 2>/dev/null || :
  fail 'signal fixture Gamescope did not start'
}
kill -TERM "$signal_launcher_pid"
wait "$signal_launcher_pid"
signal_status=$?
set -e
[[ "$signal_status" -eq 143 ]] || fail "SIGTERM was not preserved: status $signal_status"
grep -Fqx -- '--gaming-leave' "$tmp/signal-dinitui" || fail 'SIGTERM did not restore the Gaming profile'
printf 'gaming_signal_fixture launcher=prompt-exit status=143 profile=restored\n'


rm -rf "$tmp"
trap - EXIT

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
marker="$tmp/marker"
fixture="$tmp/fixture-game"


cat >"$fixture" <<EOF
#!/bin/sh
set -eu
printf 'fixture-started' > '$marker'
sleep 0.2
printf 'fixture-exited' >> '$marker'
EOF
chmod +x "$fixture"

gamescope_version=$(gamescope --version 2>&1)
printf 'gamescope_version=%s\n' "$gamescope_version"

timeout 30s gamescope \
  --backend headless \
  --nested-width 320 \
  --nested-height 200 \
  --nested-refresh 30 \
  -- "$fixture" \
  >"$tmp/gamescope.log" 2>&1 || {
    cat "$tmp/gamescope.log" >&2
    fail 'headless Gamescope fixture did not exit successfully'
  }

[[ -f "$marker" ]] || fail 'fixture did not start under Gamescope'
grep -Fqx 'fixture-startedfixture-exited' "$marker" || fail 'fixture did not exit cleanly under Gamescope'
printf 'gaming_p5_runtime gamescope=headless fixture=start-exit steam=not-launched\n'
