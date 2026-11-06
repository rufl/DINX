#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
idle="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-idle"
lock="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-lock"
live_config="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-seed-aqueous-live-config"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/swayidle" <<'EOF'
#!/bin/sh
printf 'swayidle_argv='
printf '[%s]' "$@"
printf '\n'
if [ "${DINX_LIVE_SESSION:-}" = 1 ]; then
  [ "$#" -eq 10 ] && [ "$1" = -w ] && [ "$2" = timeout ] && [ "$3" = 600 ] \
    && [ "$5" = resume ] && [ "$7" = before-sleep ] && [ "$9" = after-resume ] || exit 1
  sh -c "$4"
  sh -c "$6"
  sh -c "$8"
  sh -c "${10}"
fi
EOF
cat > "$tmp/swaylock" <<'EOF'
#!/bin/sh
printf 'swaylock_argv='
printf '[%s]' "$@"
printf '\n'
EOF
cat > "$tmp/wlopm" <<'EOF'
#!/bin/sh
printf '%s\n' "$(printf '[%s]' "$@")" >> "$DINX_WLOPM_LOG"
EOF
chmod +x "$tmp/swayidle" "$tmp/swaylock" "$tmp/wlopm"
export DINX_WLOPM_LOG="$tmp/wlopm.log"
: > "$DINX_WLOPM_LOG"

installed_idle=$(PATH="$tmp:$PATH" "$idle")
installed_lock=$(PATH="$tmp:$PATH" "$lock")
[[ "$installed_idle" == 'swayidle_argv=[-w][timeout][600][/usr/local/libexec/dinx-lock][before-sleep][/usr/local/libexec/dinx-lock]' ]] || {
  printf 'smoke_dinx_session: unexpected installed idle argv: %s\n' "$installed_idle" >&2
  exit 1
}
[[ "$installed_lock" == 'swaylock_argv=[-f]' ]] || {
  printf 'smoke_dinx_session: installed lock did not invoke swaylock: %s\n' "$installed_lock" >&2
  exit 1
}

live_idle=$(DINX_LIVE_SESSION=1 PATH="$tmp:$PATH" "$idle")
[[ "$live_idle" == 'swayidle_argv=[-w][timeout][600][wlopm --off "*"][resume][wlopm --on "*"][before-sleep][wlopm --off "*"][after-resume][wlopm --on "*"]' ]] || {
  printf 'smoke_dinx_session: unexpected live idle argv: %s\n' "$live_idle" >&2
  exit 1
}
live_lock=$(DINX_LIVE_SESSION=1 PATH="$tmp:$PATH" "$lock" 2>&1)
[[ "$live_lock" == 'dinx-lock: screen locking is disabled in the live session' ]] || {
  printf 'smoke_dinx_session: live lock was not disabled: %s\n' "$live_lock" >&2
  exit 1
}
[[ $(<"$DINX_WLOPM_LOG") == $'[--off][*]\n[--on][*]\n[--off][*]\n[--on][*]' ]] || {
  printf 'smoke_dinx_session: live output blank/wake sequence is incorrect: %s\n' "$(<"$DINX_WLOPM_LOG")" >&2
  exit 1
}

cat > "$tmp/wm.toml" <<'EOF'
[blur]
enabled = true
[opacity]
enabled = true
[keybinds]
lock_screen = "Super+Ctrl+L"
focus_left = "Super+H"
EOF
"$live_config" "$tmp/wm.toml"
grep -Fqx 'enabled = false' "$tmp/wm.toml" || { printf 'smoke_dinx_session: live effects were not disabled\n' >&2; exit 1; }
grep -Fqx 'lock_screen = []' "$tmp/wm.toml" || { printf 'smoke_dinx_session: live lock binding was not removed\n' >&2; exit 1; }
grep -Fqx 'focus_left = "Super+H"' "$tmp/wm.toml" || { printf 'smoke_dinx_session: unrelated live keybind changed\n' >&2; exit 1; }
"$live_config" "$tmp/wm.toml"
[[ $(grep -Fc 'lock_screen = []' "$tmp/wm.toml") -eq 1 ]] || {
  printf 'smoke_dinx_session: live config seeding is not idempotent\n' >&2
  exit 1
}

printf 'dinx_session_smoke live_blank=true live_lock_disabled=true installed_lock=true seed_idempotent=true\n'
