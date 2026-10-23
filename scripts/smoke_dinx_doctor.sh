#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
doctor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-doctor"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/home" "$tmp/config/shikane"
printf '# DINX wdisplays\n' > "$tmp/config/shikane/config.toml"
: > "$tmp/pacman.log"
: > "$tmp/dinit.log"

cat > "$tmp/bin/pacman" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DINX_DOCTOR_PACMAN_LOG"
if [ "$1" = -Q ]; then
  case "$2" in
    dinit|labwc|noctalia|phyto|pori|wdisplays|shikane|file-roller|gparted|dinitui|dinxpanel|dome|seafoam-settings|zls|aqueous|pearl) exit 0 ;;
  esac
fi
exit 1
EOF

cat > "$tmp/bin/dinitctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DINX_DOCTOR_DINIT_LOG"
[ "$1" = --user ] && [ "$2" = list ]
EOF

for command in labwc noctalia dinitui dinxpanel aqueous pearl phyto pori wdisplays shikane shikanectl udisksctl; do
  : > "$tmp/bin/$command"
done
chmod +x "$tmp/bin/pacman" "$tmp/bin/dinitctl" "$tmp/bin"/*

report=$(
  HOME="$tmp/home" \
  XDG_CONFIG_HOME="$tmp/config" \
  DINX_DOCTOR_PACMAN_LOG="$tmp/pacman.log" \
  DINX_DOCTOR_DINIT_LOG="$tmp/dinit.log" \
  PATH="$tmp/bin:/usr/bin:/bin" \
  "$doctor"
)

for required in \
  'schema=dinx-doctor/v1' \
  'mode=read-only' \
  'session.default=labwc+noctalia' \
  'storage.ntfs3_write=kernel-driver' \
  'package.labwc=installed' \
  'package.aqueous=installed' \
  'package.pearl=installed' \
  'package.transactions=not-run' \
  'network.access=not-run'; do
  grep -Fqx "$required" <<<"$report" || {
    printf 'smoke_dinx_doctor: missing report line: %s\n' "$required" >&2
    exit 1
  }
done

if grep -Eq '(^|[[:space:]])(-S|start|stop|restart|mount)([[:space:]]|$)' "$tmp/pacman.log" "$tmp/dinit.log"; then
  printf 'smoke_dinx_doctor: mutating command reached a fixture\n' >&2
  exit 1
fi

query_report=$(
  HOME="$tmp/home" \
  XDG_CONFIG_HOME="$tmp/config" \
  DINX_DOCTOR_PACMAN_LOG="$tmp/pacman.log" \
  DINX_DOCTOR_DINIT_LOG="$tmp/dinit.log" \
  DINX_DOCTOR_QUERY_DINIT=1 \
  PATH="$tmp/bin:/usr/bin:/bin" \
  "$doctor"
)
grep -Fqx 'dinit.user_services=available' <<<"$query_report"
grep -Fqx -- '--user list' "$tmp/dinit.log"

printf 'dinx_doctor_smoke schema=true read_only=true dinit_opt_in=true profile=true package_state=true\n'
