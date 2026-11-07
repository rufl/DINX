#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
wrapper="$repo_root/scripts/iso-tools/mksquashfs"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-final-package-prune.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

fail() {
  printf 'smoke_final_squashfs_package_exclusions: %s\n' "$*" >&2
  exit 1
}

(( EUID == 0 )) || fail 'run this smoke as root inside the ISO builder'
command -v pacman >/dev/null 2>&1 || fail 'pacman is required'
if pacman -Q linux-headers >/dev/null 2>&1; then
  builder_headers_before=present
else
  builder_headers_before=absent
fi
if pacman -Q pahole >/dev/null 2>&1; then
  builder_pahole_before=present
else
  builder_pahole_before=absent
fi

root="$work_dir/rootfs"
header_db="$root/var/lib/pacman/local/linux-headers-1.0-1"
other_db="$root/var/lib/pacman/local/dinx-prune-smoke-1.0-1"
pahole_db="$root/var/lib/pacman/local/pahole-1.0-1"
header_file="$root/usr/src/linux-fixture/include/dinx-fixture.h"
other_file="$root/usr/share/dinx-prune-smoke/keep"
pahole_file="$root/usr/bin/pahole"
mkdir -p -- "$header_db" "$pahole_db" "$other_db" \
  "$(dirname -- "$header_file")" "$(dirname -- "$pahole_file")" \
  "$(dirname -- "$other_file")" "$root/etc"
cp -- /var/lib/pacman/local/ALPM_DB_VERSION "$root/var/lib/pacman/local/ALPM_DB_VERSION"
printf '[options]\nArchitecture = auto\nInclude = %s/missing-dinx-mirrorlist\n' "$work_dir" > "$root/etc/pacman.conf"
printf 'fixture header\n' > "$header_file"
printf 'pahole fixture\n' > "$pahole_file"
printf 'preserved runtime file\n' > "$other_file"

cat > "$header_db/desc" <<'EOF'
%NAME%
linux-headers

%VERSION%
1.0-1

%DESC%
build-only kernel headers fixture

%DEPENDS%
pahole

%SIZE%
15

EOF
cat > "$pahole_db/desc" <<'EOF'
%NAME%
pahole

%VERSION%
1.0-1

%DESC%
build-only kernel header dependency fixture

%SIZE%
7

EOF
cat > "$pahole_db/files" <<'EOF'
%FILES%
usr/
usr/bin/
usr/bin/pahole
EOF
cat > "$header_db/files" <<'EOF'
%FILES%
usr/
usr/src/
usr/src/linux-fixture/
usr/src/linux-fixture/include/
usr/src/linux-fixture/include/dinx-fixture.h
EOF
cat > "$other_db/desc" <<'EOF'
%NAME%
dinx-prune-smoke

%VERSION%
1.0-1

%DESC%
retained package fixture

%SIZE%
24

EOF
cat > "$other_db/files" <<'EOF'
%FILES%
usr/
usr/share/
usr/share/dinx-prune-smoke/
usr/share/dinx-prune-smoke/keep
EOF


fake_mksquashfs="$work_dir/mksquashfs"
cat > "$fake_mksquashfs" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -ge 2 ]]
EOF
chmod 0755 "$fake_mksquashfs"
blocked_root="$work_dir/blocked-rootfs"
cp -a -- "$root" "$blocked_root"
blocked_consumer="$blocked_root/var/lib/pacman/local/dinx-pahole-consumer-1.0-1"
mkdir -p -- "$blocked_consumer"
cat > "$blocked_consumer/desc" <<'EOF'
%NAME%
dinx-pahole-consumer

%VERSION%
1.0-1

%DESC%
runtime dependency fixture

%DEPENDS%
pahole

%SIZE%
1

EOF
printf '%%FILES%%\n' > "$blocked_consumer/files"
if DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$blocked_root" "$work_dir/blocked.sfs" >"$work_dir/blocked.log" 2>&1; then
  fail 'pruning removed pahole while a retained package depends on it'
fi
[[ -d "$blocked_root/var/lib/pacman/local/linux-headers-1.0-1" \
   && -d "$blocked_root/var/lib/pacman/local/pahole-1.0-1" ]] \
  || fail 'failed dependency-safe pruning partially removed package records'
live_root="$work_dir/livefs"
cp -a -- "$root" "$live_root"
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$root" "$work_dir/rootfs.sfs"

[[ ! -e "$header_db" ]] || fail 'linux-headers package record remains in final rootfs layer'
[[ ! -e "$header_file" ]] || fail 'linux-headers payload remains in final rootfs layer'
[[ ! -e "$pahole_db" ]] || fail 'pahole package record remains in final rootfs layer'
[[ ! -e "$pahole_file" ]] || fail 'pahole payload remains in final rootfs layer'
[[ -d "$other_db" && -f "$other_file" ]] \
  || fail 'pruning modified an unrelated package or runtime file'
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$live_root" "$work_dir/livefs.sfs"
[[ ! -e "$live_root/var/lib/pacman/local/linux-headers-1.0-1" ]] \
  || fail 'linux-headers package record remains in final livefs layer'
[[ ! -e "$live_root/usr/src/linux-fixture/include/dinx-fixture.h" ]] \
  || fail 'linux-headers payload remains in final livefs layer'
[[ ! -e "$live_root/var/lib/pacman/local/pahole-1.0-1" ]] \
  || fail 'pahole package record remains in final livefs layer'
[[ ! -e "$live_root/usr/bin/pahole" ]] \
  || fail 'pahole payload remains in final livefs layer'
[[ -d "$live_root/var/lib/pacman/local/dinx-prune-smoke-1.0-1" \
   && -f "$live_root/usr/share/dinx-prune-smoke/keep" ]] \
  || fail 'livefs pruning modified an unrelated package or runtime file'
if pacman -Q linux-headers >/dev/null 2>&1; then
  builder_headers_after=present
else
  builder_headers_after=absent
fi
if pacman -Q pahole >/dev/null 2>&1; then
  builder_pahole_after=present
else
  builder_pahole_after=absent
fi
[[ "$builder_headers_after" == "$builder_headers_before" ]] \
  || fail 'pruning changed linux-headers in the ISO builder environment'
[[ "$builder_pahole_after" == "$builder_pahole_before" ]] \
  || fail 'pruning changed pahole in the ISO builder environment'

printf 'final_squashfs_package_prune_smoke builder_headers_unchanged=%s builder_pahole_unchanged=%s rootfs_headers=false rootfs_pahole=false livefs_headers=false livefs_pahole=false unrelated_payload_preserved=true\n' \
  "$builder_headers_after" "$builder_pahole_after"

