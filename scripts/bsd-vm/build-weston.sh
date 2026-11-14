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
  xcb-util-cursor libXcursor libxkbcommon xwayland >>"$LOG" 2>&1
log "== deps exit=$?"

cd "$W" || exit 1
if [ ! -d weston ]; then
  git clone --depth 1 --branch 14.0.2 \
    https://gitlab.freedesktop.org/wayland/weston.git >>"$LOG" 2>&1
fi
log "== clone exit=$?"
cd weston || exit 1
rm -rf build
meson setup build \
    -Dprefix=/usr/local \
    -Dbackend-drm=true \
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
    -Dpipewire=false \
    -Ddemo-clients=false \
    -Dtests=false \
    -Ddoc=false \
    -Dwcap-decode=false >>"$LOG" 2>&1
  log "== meson setup exit=$?"
ninja -C build >>"$LOG" 2>&1
log "== ninja exit=$?"
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
        json.dump(m, open(p, "w"), separators=(",", ":"))
PY
  (cd "$meta/inject" && tar -P -cf "$REPO/$name-$version.pkg" -s '|^usr|/usr|' \
    +COMPACT_MANIFEST +MANIFEST usr) >>"$LOG" 2>&1
  log "== shlibs_provided injected into $name exit=$?"
fi
pkg repo "$REPO" >>"$LOG" 2>&1
log "== pkg repo exit=$?"
log "== WESTON_DONE"
