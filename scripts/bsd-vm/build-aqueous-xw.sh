#!/bin/sh
# Rebuild ONLY Aqueous with -Dxwayland=true (targeted; no pearl/greetd rebuild).
#   1. Rebuild libdinxcompat.so: Zig-visible symbols (dinxcompat.c) + the
#      Linux->FreeBSD ABI translation layer (dinxlinux.c).
#   2. Restore pristine Aqueous sources so patches apply idempotently.
#   3. Apply the FreeBSD patches (bsd_compat shim + call-site rewrite).
#   4. Build with Xwayland enabled.
set -u
W=/root/build
ZIG_DIR=$(ls -d "$W"/zig-x86_64-freebsd-* 2>/dev/null | head -1)
export PATH="$ZIG_DIR:$PATH"
LOG=/tmp/aq-xw.log
: > "$LOG"
cd "$W" || exit 1

# 1. compat shim: Zig-visible symbols + the Linux->FreeBSD ABI layer
cc -shared -fPIC -O2 -o /usr/local/lib/libdinxcompat.so \
   "$W/dinxcompat.c" "$W/dinxlinux.c" >>"$LOG" 2>&1
echo "== dinxcompat rebuild exit=$?" >>"$LOG"

# 2. pristine sources (undo stale mutations from earlier runs)
(cd "$W/Aqueous" && git checkout -- . 2>>"$LOG") || true

# 3. patches (installs bsd_compat.zig, rewrites linux.<syscall> call sites)
python3 patch-freebsd.py "$W" >>"$LOG" 2>&1 || echo "patch failed" >>"$LOG"
echo "== patch-freebsd exit=$?" >>"$LOG"
grep -c "dinx_self_exe_path" "$W/Aqueous/compositor/aqueous/xwayland_dpi.zig" >>"$LOG" 2>&1
grep -rc "bsdcompat\." "$W/Aqueous/compositor/aqueous/wm/output/Service.zig" >>"$LOG" 2>&1

# 4. build with xwayland
AQ="$W/Aqueous/compositor"
cd "$AQ" || exit 1
zig build -Doptimize=ReleaseSafe -Dxwayland=true >>"$LOG" 2>&1
echo "== aqueous xwayland build exit=$?" >>"$LOG"
ls -la zig-out/bin/aqueous >>"$LOG" 2>&1
echo "== AQ_XW_DONE" >>"$LOG"
