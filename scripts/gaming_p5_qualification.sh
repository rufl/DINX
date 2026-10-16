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
printf '%s\n' "$*" > "$DINX_GAMESCOPE_ARGS"
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
[ "$#" -gt 0 ] || exit 64
shift
exec "$@"
EOF
cat >"$tmp/bin/steam" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" > "$DINX_STEAM_ARGS"
printf 'steam-fixture-started' > "$DINX_STEAM_MARKER"
printf 'steam-fixture-exited' >> "$DINX_STEAM_MARKER"
EOF
chmod +x "$tmp/bin/gamescope" "$tmp/bin/steam"
PATH="$tmp/bin:$PATH" \
  DINX_GAMESCOPE_ARGS="$tmp/gamescope-args" \
  DINX_STEAM_ARGS="$tmp/steam-args" \
  DINX_STEAM_MARKER="$tmp/steam-marker" \
  "$launcher"
grep -Fqx -- '--backend drm --steam --fullscreen -- steam -tenfoot' "$tmp/gamescope-args" || fail 'launcher Gamescope argv is incorrect'
grep -Fqx -- '-tenfoot' "$tmp/steam-args" || fail 'launcher Steam argv is incorrect'
grep -Fqx 'steam-fixture-startedsteam-fixture-exited' "$tmp/steam-marker" || fail 'launcher did not return after Steam exit'
printf 'gaming_session_fixture launcher=start-exit gamescope_argv=true steam_argv=true\n'

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
