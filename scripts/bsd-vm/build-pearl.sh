#!/bin/sh
# Rebuild ONLY Pearl (targeted). Applies the FreeBSD patches first (incl. #27,
# which strips GTK 4.22-only `backdrop-filter` CSS embedded into the binary).
set -u
W=/root/build
ZIG_DIR=$(ls -d "$W"/zig-x86_64-freebsd-* 2>/dev/null | head -1)
export PATH="$ZIG_DIR:$PATH"
LOG="$W/pearl-build.log"
: > "$LOG"
cd "$W" || exit 1

# Restore pristine Pearl sources so patches apply idempotently (previous runs
# may have left a broken variant, e.g. std.ascii.indexOfIgnoreCase).
(cd "$W/pearl" && git checkout -- . 2>>"$LOG") || true
python3 patch-freebsd.py "$W" >>"$LOG" 2>&1 || echo "patch failed" >>"$LOG"
echo "== patch-freebsd exit=$?" >>"$LOG"
grep -c "backdrop-filter" "$W/pearl/resources/style.css" >>"$LOG" 2>&1
grep -c 'eqlIgnoreCase(environment.desktop' "$W/pearl/src/core/startup.zig" >>"$LOG" 2>&1

cd "$W/pearl" || exit 1
zig build -Doptimize=ReleaseSafe >>"$LOG" 2>&1
echo "== pearl build exit=$?" >>"$LOG"
ls -la zig-out/bin/ >>"$LOG" 2>&1
echo "== PEARL_DONE" >>"$LOG"
