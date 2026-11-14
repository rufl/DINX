#!/bin/sh
# Rebuild ONLY Aqueous with -Dxwayland=true (targeted; no pearl/greetd rebuild).
# 1. Rebuild libdinxcompat (adds dinx_self_exe_path for /proc/self/exe).
# 2. Restore pristine Aqueous sources so patches apply idempotently.
# 3. Apply FreeBSD patches (incl. #24 xwayland_dpi errno/environ/self-exe).
# 4. Build with Xwayland enabled.
set -u
W=/root/build
ZIG_DIR=$(ls -d "$W"/zig-x86_64-freebsd-* 2>/dev/null | head -1)
export PATH="$ZIG_DIR:$PATH"
LOG=/tmp/aq-xw.log
: > "$LOG"
cd "$W" || exit 1

# 1. compat shim with the new exe-path helper
cc -shared -fPIC -O2 -o /usr/local/lib/libdinxcompat.so "$W/dinxcompat.c" >>"$LOG" 2>&1
echo "== dinxcompat rebuild exit=$?" >>"$LOG"

# 2. pristine sources (undo stale mutations from earlier runs)
(cd "$W/Aqueous" && git checkout -- . 2>>"$LOG") || true

# 3. patches
python3 patch-freebsd.py "$W" >>"$LOG" 2>&1 || echo "patch failed" >>"$LOG"
echo "== patch-freebsd exit=$?" >>"$LOG"
grep -c "dinx_self_exe_path" "$W/Aqueous/compositor/aqueous/xwayland_dpi.zig" >>"$LOG" 2>&1

# 4. build with xwayland
AQ="$W/Aqueous/compositor"
cd "$AQ" || exit 1
zig build -Doptimize=ReleaseSafe -Dxwayland=true >>"$LOG" 2>&1
echo "== aqueous xwayland build exit=$?" >>"$LOG"
ls -la zig-out/bin/aqueous >>"$LOG" 2>&1
echo "== AQ_XW_DONE" >>"$LOG"
