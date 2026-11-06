#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
wrapper="$repo_root/scripts/iso-tools/mksquashfs"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-final-package-prune.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

fail() {
  printf 'smoke_final_rootfs_package_exclusions: %s\n' "$*" >&2
  exit 1
}

(( EUID == 0 )) || fail 'run this smoke as root inside the ISO builder'
command -v pacman >/dev/null 2>&1 || fail 'pacman is required'
pacman -Q linux-headers >/dev/null 2>&1 \
  || fail 'linux-headers must remain installed in the ISO builder'

root="$work_dir/rootfs"
header_db="$root/var/lib/pacman/local/linux-headers-1.0-1"
other_db="$root/var/lib/pacman/local/dinx-prune-smoke-1.0-1"
header_file="$root/usr/src/linux-fixture/include/dinx-fixture.h"
other_file="$root/usr/share/dinx-prune-smoke/keep"
mkdir -p -- "$header_db" "$other_db" "$(dirname -- "$header_file")" "$(dirname -- "$other_file")" "$root/etc"
cp -- /var/lib/pacman/local/ALPM_DB_VERSION "$root/var/lib/pacman/local/ALPM_DB_VERSION"
printf '[options]\nArchitecture = auto\n' > "$root/etc/pacman.conf"
printf 'fixture header\n' > "$header_file"
printf 'preserved runtime file\n' > "$other_file"

cat > "$header_db/desc" <<'EOF'
%NAME%
linux-headers

%VERSION%
1.0-1

%DESC%
build-only kernel headers fixture

%SIZE%
15

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
DINX_MKSQUASHFS_REAL="$fake_mksquashfs" \
  "$wrapper" "$root" "$work_dir/rootfs.sfs"

[[ ! -e "$header_db" ]] || fail 'linux-headers package record remains in final rootfs layer'
[[ ! -e "$header_file" ]] || fail 'linux-headers payload remains in final rootfs layer'
[[ -d "$other_db" && -f "$other_file" ]] \
  || fail 'pruning modified an unrelated package or runtime file'
pacman -Q linux-headers >/dev/null 2>&1 \
  || fail 'pruning removed linux-headers from the build environment'

printf 'final_rootfs_package_prune_smoke builder_headers=true final_rootfs_headers=false unrelated_payload_preserved=true\n'
