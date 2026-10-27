#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
service="$root/distro/packages/pori/pori-mount-service"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fakebin="$tmp/bin"
state="$tmp/state"
mkdir -p "$fakebin" "$state" "$tmp/mnt"
: >"$tmp/source"
printf 'unmounted\n' >"$state/status"
printf '1\n' >"$state/fail_once"

cat >"$fakebin/mountpoint" <<'EOF'
#!/bin/sh
set -eu
[ "${1:-}" = -q ]
[ "$(cat "$PORI_SMOKE_STATE/status")" = mounted ]
EOF
cat >"$fakebin/mount" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$PORI_SMOKE_STATE/mount.log"
if [ "$(cat "$PORI_SMOKE_STATE/fail_once")" = 1 ]; then
  printf '0\n' >"$PORI_SMOKE_STATE/fail_once"
  exit 1
fi
printf 'mounted\n' >"$PORI_SMOKE_STATE/status"
EOF
cat >"$fakebin/umount" <<'EOF'
#!/bin/sh
set -eu
printf 'unmounted\n' >"$PORI_SMOKE_STATE/status"
EOF
cat >"$fakebin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$fakebin"/*

export PORI_SMOKE_STATE="$state"
export PORI_MOUNTPOINT_BIN="$fakebin/mountpoint"
export PORI_MOUNT_BIN="$fakebin/mount"
export PORI_UMOUNT_BIN="$fakebin/umount"
export PORI_SLEEP_BIN="$fakebin/sleep"

"$service" "$tmp/source" "$tmp/mnt" ntfs3 defaults,noatime &
pid=$!
for _ in $(seq 1 50); do
  if grep -Fqx mounted "$state/status"; then
    break
  fi
  sleep 0.01
done
grep -Fqx mounted "$state/status"
kill -TERM "$pid"
if wait "$pid"; then
  exit_code=0
else
  exit_code=$?
fi
[ "$exit_code" -eq 143 ]
grep -Fqx unmounted "$state/status"
grep -Fq -- '-t ntfs3 -o defaults,noatime' "$state/mount.log"

printf 'pori_mount_service_smoke retry=true ntfs3=true supervised_unmount=true\n'
