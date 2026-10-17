#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
idle="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-idle"
lock="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-lock"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/swayidle" <<'EOF'
#!/bin/sh
printf 'swayidle_argv='
printf '[%s]' "$@"
printf '\n'
EOF
cat > "$tmp/swaylock" <<'EOF'
#!/bin/sh
printf 'swaylock_argv='
printf '[%s]' "$@"
printf '\n'
EOF
chmod +x "$tmp/swayidle" "$tmp/swaylock"

idle_output=$(PATH="$tmp:$PATH" "$idle")
lock_output=$(PATH="$tmp:$PATH" "$lock")
grep -Fq 'swayidle_argv=[-w][timeout][600][/usr/local/libexec/dinx-lock][before-sleep][/usr/local/libexec/dinx-lock]' <<<"$idle_output" || {
  printf 'smoke_dinx_session: unexpected idle argv: %s\n' "$idle_output" >&2
  exit 1
}
grep -Fq 'swaylock_argv=[-f]' <<<"$lock_output" || {
  printf 'smoke_dinx_session: unexpected lock argv: %s\n' "$lock_output" >&2
  exit 1
}
printf 'dinx_session_smoke lock_argv=true idle_argv=true before_suspend=true\n'
