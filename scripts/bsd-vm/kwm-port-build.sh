#!/bin/sh
# Build kwm for FreeBSD inside the VM: apply patch-kwm-freebsd.py, then zig build.
# Usage: sh kwm-port-build.sh <patch-url>
set -u
W=/root/kwmbuild
K=$W/kwm
LOG=$W/kwm-port.log
: > "$LOG"
exec >>"$LOG" 2>&1
# The pinned FreeBSD toolchain tarball unpacked by setup-build-vm.sh; globbed
# so a toolchain bump does not silently break this script.
ZIG_DIR=$(ls -d "$W"/zig-x86_64-freebsd-* 2>/dev/null | head -1)
[ -n "$ZIG_DIR" ] || { echo "NO_ZIG_TOOLCHAIN in $W"; exit 1; }
export PATH="$ZIG_DIR:$PATH"

echo "== kwm-port-build start $(date -u +%FT%TZ)"
zig version

echo "== build deps present? =="
for c in fcft wayland-client xkbcommon pixman-1; do
  printf '%s: ' "$c"
  pkg-config --exists "$c" 2>/dev/null && echo yes || echo NO
done
command -v scdoc >/dev/null 2>&1 && echo "scdoc: yes" || echo "scdoc: NO"
command -v pkg-config >/dev/null 2>&1 && echo "pkg-config: yes" || echo "pkg-config: NO"

echo "== fetching patch =="
fetch -q -o "$W/patch-kwm-freebsd.py" "$1" || { echo "FETCH_FAILED"; exit 1; }
echo "== patch url = $1"

echo "== restoring pristine kwm/src so the run is reproducible =="
git -C "$K" checkout -- src 2>&1 || echo "(git restore failed; continuing)"
git -C "$K" status --porcelain | head -5

echo "== applying patch =="
# The e2e guest ships python3.12 without a bare `python3` symlink; the build
# VM (setup-build-vm.sh) installs python3. Resolve whichever exists.
PY=$(command -v python3 || command -v python3.12 || command -v python3.11 || echo "")
[ -n "$PY" ] || { echo "NO_PYTHON"; exit 1; }
echo "python = $PY"
"$PY" "$W/patch-kwm-freebsd.py" "$W"
echo "patch_rc=$?"

echo "== zig build (fetch deps first) =="
cd "$K" || exit 1
zig build --fetch >>"$LOG" 2>&1
echo "fetch_rc=$?"
zig build -Doptimize=ReleaseSafe -Dbar=true -Dkwim=true
echo "build_rc=$?"
ls -la zig-out/bin 2>&1 | head -10
echo "KWM_PORT_BUILD_DONE"
