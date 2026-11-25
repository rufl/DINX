#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
<<<<<<< HEAD
idle="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-idle"
lock="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/libexec/dinx-lock"
=======
overlay="$root/distro/iso/iso-profiles/dinx/root-overlay"
idle="$overlay/usr/local/libexec/dinx-idle"
lock="$overlay/usr/local/libexec/dinx-lock"
river_session="$overlay/usr/local/libexec/dinx-river-session"
>>>>>>> main
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

# Installed sessions keep the swaylock timeout and the suspend lock path.
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

# The live session may only blank displays: no lock command, no lock action.
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

<<<<<<< HEAD

printf 'dinx_session_smoke live_blank=true live_lock_disabled=true installed_lock=true\n'
=======
# The River wrapper's live-session lock-override block, executed verbatim in a
# throwaway HOME: it must hide the lock action and never clobber a user file.
live_block="$tmp/live-lock-override.sh"
awk '
  /^  data_home=\$\{XDG_DATA_HOME/ { capture = 1 }
  capture { print }
  capture && /^  fi$/ { exit }
' "$river_session" >"$live_block"
[[ -s "$live_block" ]] || {
  printf 'smoke_dinx_session: the live lock-override block is missing from the River session wrapper\n' >&2
  exit 1
}
grep -Fq 'Hidden=true' "$live_block" || {
  printf 'smoke_dinx_session: the live lock-override block does not hide the lock action\n' >&2
  exit 1
}
live_home="$tmp/live-home"
mkdir -p "$live_home"
run_live_block() {
  XDG_DATA_HOME="$live_home/.local/share" sh -eu -c '. "$1"' sh "$live_block"
}
run_live_block
live_override="$live_home/.local/share/applications/dinx-lock.desktop"
grep -Fq 'Hidden=true' "$live_override" || {
  printf 'smoke_dinx_session: live session did not hide the screen-lock action\n' >&2
  exit 1
}
printf '[Desktop Entry]\nType=Application\nName=My own lock\nHidden=false\n' >"$live_override"
run_live_block
grep -Fq 'Name=My own lock' "$live_override" || {
  printf 'smoke_dinx_session: live lock override replaced a user-owned file\n' >&2
  exit 1
}
rm -f "$live_override"
run_live_block
[[ $(grep -Fc 'Hidden=true' "$live_override") -eq 1 ]] || {
  printf 'smoke_dinx_session: live lock override seeding is not idempotent\n' >&2
  exit 1
}

printf 'dinx_session_smoke live_blank=true live_lock_disabled=true installed_lock=true live_lock_override=hidden+preserves_user_file idempotent=true\n'
>>>>>>> main
