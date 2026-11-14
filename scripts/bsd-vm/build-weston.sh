#!/bin/sh
# Native FreeBSD build of Weston (reference compositor) with Xwayland, plus a
# real dinx-weston .pkg. Run INSIDE the FreeBSD build VM as root.
# Weston replaces Aqueous as the session compositor: its Wayland socket and
# Xwayland support work on FreeBSD, unlike the Aqueous port (see STATUS doc).
set -u
W=${1:-/root/build}
LOG="$W/build-weston.log"
REPO="$W/repo"
mkdir -p "$REPO"
: > "$LOG"
log() { printf '%s\n' "$*" | tee -a "$LOG"; }

pkg install -y meson ninja pkgconf git-lite wayland-protocols libxkbcommon \
  pixman libinput libevdev libmtdev libdrm seatd cairo pango lcms2 \
  xcb-util-cursor libXcursor libxkbcommon xwayland xterm >>"$LOG" 2>&1
log "== deps exit=$?"

cd "$W" || exit 1
if [ ! -d weston ]; then
  git clone --depth 1 --branch 14.0.2 \
    https://gitlab.freedesktop.org/wayland/weston.git >>"$LOG" 2>&1
fi
log "== clone exit=$?"
cd weston || exit 1
# FreeBSD has no ETIME (Linux errno); ETIMEDOUT is the equivalent.
sed -i '' 's/errno = ETIME;/errno = ETIMEDOUT;/' shared/file-util.c
# glibc-only program name; FreeBSD provides getprogname() in stdlib.h.
sed -i '' 's/program_invocation_short_name/getprogname()/g' shared/xalloc.h
grep -rl 'program_invocation_short_name' --include='*.c' --include='*.h' . \
  | xargs sed -i '' 's/program_invocation_short_name/getprogname()/g'
sed -i '' 's|#include <linux/ioctl.h>|#include <sys/ioctl.h>|' libweston/linux-sync-file-uapi.h
sed -i '' 's|#include <values.h>|#include <limits.h>\
#include <float.h>|' libweston/input.c
grep -rl 'CLOCK_MONOTONIC_RAW' --include='*.c' --include='*.h' . \
  | xargs sed -i '' 's/CLOCK_MONOTONIC_RAW/CLOCK_MONOTONIC/g'
sed -i '' 's|#include <pty.h>|#include <libutil.h>|' clients/terminal.c
# FreeBSD libc expects the executable/library to provide `environ`.
sed -i '' '/^char \*\*environ;$/d' shared/process-util.c
grep -q 'weak)) char \*\*environ;' shared/process-util.c \
  || sed -i '' '1i\
__attribute__((weak)) char **environ;
' shared/process-util.c
# epoll-shim must be linked into every target (epoll_shim_fcntl).
export LDFLAGS="-L/usr/local/lib -lepoll-shim -lutil"
# Linux uapi headers used by weston's sync-file support: shim them.
mkdir -p /usr/local/include/linux
printf '#include <sys/ioctl.h>\n' > /usr/local/include/linux/ioctl.h
printf '#include <sys/types.h>\n#include <stdint.h>\ntypedef uint8_t __u8;\ntypedef uint16_t __u16;\ntypedef uint32_t __u32;\ntypedef uint64_t __u64;\ntypedef int8_t __s8;\ntypedef int16_t __s16;\ntypedef int32_t __s32;\ntypedef int64_t __s64;\n' > /usr/local/include/linux/types.h
RECONF=
[ -f build/build.ninja ] && RECONF=--reconfigure
meson setup $RECONF build \
    -Drenderer-gl=false \
    -Dprefix=/usr/local \
    -Dbackend-drm=false \
    -Dbackend-default=headless \
    -Dbackend-headless=true \
    -Dbackend-wayland=true \
    -Dbackend-x11=false \
    -Dbackend-rdp=false \
    -Dbackend-vnc=false \
    -Dbackend-pipewire=false \
    -Dxwayland=true \
    -Dshell-desktop=true \
    -Dshell-kiosk=true \
    -Dshell-ivi=false \
    -Dshell-fullscreen=false \
    -Dcolor-management-lcms=true \
    -Dimage-jpeg=false \
    -Dimage-webp=false \
    -Dsystemd=false \
    -Dremoting=false \
    '-Dtools=[]' \
    -Dpipewire=false \
    '-Dsimple-clients=[]' \
    -Ddemo-clients=false \
    -Dtests=false \
    -Ddoc=false \
    -Dwcap-decode=false >>"$LOG" 2>&1
  log "== meson setup exit=$?"
ninja -C build >>"$LOG" 2>&1
rc=$?
grep -A6 -m2 "FAILED" "$LOG" > "$W/weston-errors.txt" 2>/dev/null || true
log "== ninja exit=$rc"
ninja -C build install >>"$LOG" 2>&1
log "== install exit=$?"

# --- package dinx-weston (same proven pattern as build-native.sh) ----------
name=dinx-weston
version=14.0.2
meta="$W/meta-$name"
stage="$W/stage-$name"
rm -rf "$meta" "$stage"
mkdir -p "$meta" "$stage/usr/local"
for p in bin lib/weston lib/libweston-14.so lib/libweston-14.so.14 \
         lib/libweston-14.so.14.0.2 libdata/pkgconfig include/libweston-14 \
         share/weston share/wayland-sessions libexec; do
  if [ -e "/usr/local/$p" ]; then
    mkdir -p "$stage/usr/local/$(dirname "$p")"
    cp -a "/usr/local/$p" "$stage/usr/local/$p"
  fi
done
cat > "$meta/+MANIFEST" <<EOF
name: $name
version: "$version"
origin: dinx/weston
comment: Weston compositor with Xwayland (native FreeBSD build)
maintainer: trafael@dinx.org
prefix: /usr/local
EOF
printf '%s\n' "Weston compositor with Xwayland (native FreeBSD build)" > "$meta/+DESC"
(cd "$stage" && find . -type f | sed 's|^\./|/|') > "$meta/plist"
pkg create -m "$meta" -p "$meta/plist" -r "$stage" -o "$REPO" >>"$LOG" 2>&1
log "== pkg create $name exit=$?"
prov=$(sed -n 's|^/usr/local/lib/\(lib[^/]*\.so[^/]*\)$|\1|p' "$meta/plist" \
  | sed 's/.*/"&"/' | paste -sd, -)
if [ -n "$prov" ]; then
  rm -rf "$meta/inject"
  mkdir -p "$meta/inject"
  tar -xf "$REPO/$name-$version.pkg" -C "$meta/inject" >>"$LOG" 2>&1
  python3 - "$meta/inject" "[$prov]" >>"$LOG" 2>&1 <<'PY'
import json, os, sys
d, prov = sys.argv[1], json.loads(sys.argv[2])
for n in ("+MANIFEST", "+COMPACT_MANIFEST"):
    p = os.path.join(d, n)
    if os.path.exists(p):
        m = json.load(open(p))
        m["shlibs_provided"] = prov
        m.pop("shlibs_required", None)
        json.dump(m, open(p, "w"), separators=(",", ":"))
PY
  (cd "$meta/inject" && tar -P -cf "$REPO/$name-$version.pkg" -s '|^usr|/usr|' \
    +COMPACT_MANIFEST +MANIFEST usr) >>"$LOG" 2>&1
  log "== shlibs_provided injected into $name exit=$?"
fi
pkg repo "$REPO" >>"$LOG" 2>&1
log "== pkg repo exit=$?"
log "== WESTON_DONE"
