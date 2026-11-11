#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
wrapper="$repo_root/scripts/iso-tools/mksquashfs"

fail() {
  printf 'check_dinx_compression: %s\n' "$*" >&2
  exit 1
}

[[ -x "$wrapper" ]] || fail "compression wrapper is missing or not executable: $wrapper"
for required in \
  '-comp xz' \
  '-b 1M' \
  '-Xbcj x86' \
  '-Xdict-size 1M' \
  "'usr/src/linux*'" \
  "'var/cache/pacman/pkg/*'" \
  "'var/log/*'" \
  'strip_documentation()' \
  '! -name SOURCE' \
  'usr/share/man' \
  'usr/share/gtk-doc'; do
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
mkdir -p "$fixture_root/usr/share/doc/demo" "$fixture_root/usr/share/man/man1"
printf 'source provenance\n' > "$fixture_root/usr/share/doc/demo/SOURCE"
printf 'license\n' > "$fixture_root/usr/share/doc/demo/LICENSE"
printf 'runtime-irrelevant documentation\n' > "$fixture_root/usr/share/doc/demo/README"
printf 'manual\n' > "$fixture_root/usr/share/man/man1/demo.1"
DINX_MKSQUASHFS_REAL="$fake" \
DINX_COMPRESSION_ARGS="$args_file" \
  "$wrapper" "$fixture_root" "$work_dir/fixture.img"
[[ -f "$fixture_root/usr/share/doc/demo/SOURCE" ]] \
  || fail 'source provenance was stripped from the final filesystem'
[[ -f "$fixture_root/usr/share/doc/demo/LICENSE" ]] \
  || fail 'license artifact was stripped from the final filesystem'
[[ ! -e "$fixture_root/usr/share/doc/demo/README" ]] \
  || fail 'ordinary documentation remains in the final filesystem'
[[ ! -e "$fixture_root/usr/share/man" ]] \
  || fail 'manual pages remain in the final filesystem'

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
xz
-b
1M
-Xbcj
x86
-Xdict-size
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

printf 'dinx_compression_contract compression=xz block=1M dict=1M level=tool-default bcj=x86 excludes=kernel-source+pacman-cache+logs override_safe=true\n'
