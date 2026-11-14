#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)
wrapper="$repo_root/scripts/iso-tools/mksquashfs"

fail() {
  printf 'check_dinx_compression: %s\n' "$*" >&2
  exit 1
}

[[ -x "$wrapper" ]] || fail "compression wrapper is missing or not executable: $wrapper"
for required in \
  '-comp zstd' \
  '-Xcompression-level 19' \
  '-b 1M' \
  "'usr/src/linux*'" \
  "'var/cache/pacman/pkg/*'" \
  "'var/log/*'" \
  'strip_documentation()' \
  'strip_build_metadata()' \
  'usr/share/man' \
  'usr/share/gtk-doc' \
  'usr/share/gir-1.0'; do
  grep -Fq -- "$required" "$wrapper" || fail "compression wrapper is missing: $required"
done

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
args_file="$work_dir/args"
fake="$work_dir/mksquashfs"
cat > "$fake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$DINX_COMPRESSION_ARGS"
EOF
chmod +x "$fake"

fixture_root="$work_dir/rootfs"
mkdir -p "$fixture_root/usr/share/doc/demo" "$fixture_root/usr/share/man/man1" \
  "$fixture_root/usr/include/ghostty/vt" "$fixture_root/usr/include/gtk-4.0" \
  "$fixture_root/usr/share/gir-1.0" "$fixture_root/usr/lib/cmake/demo" \
  "$fixture_root/usr/lib/pkgconfig" "$fixture_root/usr/share/vala" \
  "$fixture_root/usr/share/aclocal"
printf 'license\n' > "$fixture_root/usr/share/doc/demo/LICENSE"
printf 'runtime-irrelevant documentation\n' > "$fixture_root/usr/share/doc/demo/README"
printf 'manual\n' > "$fixture_root/usr/share/man/man1/demo.1"
printf 'vt header required by the Deetty build contract\n' > "$fixture_root/usr/include/ghostty/vt.h"
printf 'nested vt header\n' > "$fixture_root/usr/include/ghostty/vt/grid.h"
printf 'build-only header\n' > "$fixture_root/usr/include/gtk-4.0/gtk.h"
printf 'build-only introspection source\n' > "$fixture_root/usr/share/gir-1.0/Gtk-4.0.gir"
printf 'build-only cmake config\n' > "$fixture_root/usr/lib/cmake/demo/demo.cmake"
printf 'build-only pkg-config record\n' > "$fixture_root/usr/lib/pkgconfig/demo.pc"
printf 'build-only vala binding\n' > "$fixture_root/usr/share/vala/demo.vapi"
printf 'build-only aclocal macro\n' > "$fixture_root/usr/share/aclocal/demo.m4"
DINX_MKSQUASHFS_REAL="$fake" \
DINX_COMPRESSION_ARGS="$args_file" \
  "$wrapper" "$fixture_root" "$work_dir/fixture.img"
[[ ! -e "$fixture_root/usr/share/doc" ]] \
  || fail 'documentation directory remains in the final filesystem'
[[ ! -e "$fixture_root/usr/share/man" ]] \
  || fail 'manual pages remain in the final filesystem'
for build_metadata in usr/share/gir-1.0 usr/lib/cmake usr/lib/pkgconfig usr/share/vala usr/share/aclocal; do
  [[ ! -e "$fixture_root/$build_metadata" ]] \
    || fail "build-only metadata remains in the final filesystem: $build_metadata"
done
[[ ! -e "$fixture_root/usr/include/gtk-4.0" ]] \
  || fail 'build-only headers remain in the final filesystem'
[[ -f "$fixture_root/usr/include/ghostty/vt.h" \
   && -f "$fixture_root/usr/include/ghostty/vt/grid.h" ]] \
  || fail 'the ghostty VT headers required by the Deetty build contract were stripped'

DINX_MKSQUASHFS_REAL="$fake" \
DINX_COMPRESSION_ARGS="$args_file" \
  "$wrapper" rootfs.img output.img -processors 4 \
  -comp=zstd -b=128K -Xbcj=arm -Xcompression-level=1 -Xdict-size=64K \
  -wildcards -e old-exclude

guard_output=''
if guard_output=$(DINX_MKSQUASHFS_REAL="$wrapper" "$wrapper" rootfs.img output.img 2>&1); then
  guard_status=0
else
  guard_status=$?
fi
[[ "$guard_status" -eq 125 ]] || fail 'wrapper did not reject self-recursion'
grep -Fq 'real binary resolves to the wrapper itself' <<<"$guard_output" \
  || fail 'wrapper self-recursion diagnostic is missing'


expected=$(cat <<'EOF'
rootfs.img
output.img
-processors
4
-wildcards
-e
old-exclude
-comp
zstd
-Xcompression-level
19
-b
1M
-wildcards
-e
usr/src/linux*
var/cache/pacman/pkg/*
var/log/*
EOF
)
actual=$(cat "$args_file")
[[ "$actual" == "$expected" ]] || {
  printf 'expected arguments:\n%s\nactual arguments:\n%s\n' "$expected" "$actual" >&2
  fail 'wrapper did not enforce the deterministic compression arguments'
}

printf 'dinx_compression_contract compression=zstd level=19 block=1M excludes=kernel-source+pacman-cache+logs override_safe=true\n'
