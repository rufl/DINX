#!/bin/sh
# Native FreeBSD build of the DINX desktop stack, run INSIDE a FreeBSD VM.
# Builds Aqueous (Zig/wlroots), Pearl (Zig/GTK4) and greetd (cargo), then
# packages real .pkg files and a local repository catalog with pkg-create(8).
# Usage: sh build-native.sh [workdir]   (default /root/build)
set -u
W=${1:-/root/build}
ZIG_DIR=$(ls -d "$W"/zig-x86_64-freebsd-* 2>/dev/null | head -1)
export PATH="$ZIG_DIR:$PATH"
LOG="$W/build-native.log"
REPO="$W/repo"
mkdir -p "$REPO"
: > "$LOG"

log() { printf '%s\n' "$*" | tee -a "$LOG"; }
stamp() { printf '%s %s\n' "$(date +%s)" "$1" >> "$W/times.log"; }
stamp start

zig version | tee -a "$LOG"

build_zig() {
  name=$1
  dir=$2
  shift 2
  log "== building $name in $dir (flags: $*)"
  (cd "$dir" && zig build -Doptimize=ReleaseSafe "$@") >>"$LOG" 2>&1
  rc=$?
  log "== $name zig build exit=$rc"
  return $rc
}

# FreeBSD port patches (idempotent). Upstream targets Linux; these adapt the
# C headers and the pkg-config version floors to the FreeBSD quarterly set.
apply_freebsd_patches() {
  aq="$W/Aqueous/compositor/aqueous/c.h"
  if [ -f "$aq" ] && grep -q '#include <linux/input-event-codes.h>' "$aq" \
     && ! grep -q '__FreeBSD__' "$aq"; then
    sed -i '' 's|#include <linux/input-event-codes.h>|#ifdef __FreeBSD__\
#include <dev/evdev/input-event-codes.h>\
#else\
#include <linux/input-event-codes.h>\
#endif|' "$aq"
    log "== patched aqueous c.h input-event-codes for FreeBSD"
  fi
  pz="$W/pearl/build.zig"
  if [ -f "$pz" ]; then
    sed -i '' 's/"gtk4 >= 4.22.5"/"gtk4 >= 4.20.4"/' "$pz"
    sed -i '' '/"pam >= 1.7.2",/d' "$pz"
    log "== patched pearl build.zig floors (gtk4 quarterly, base libpam)"
  fi
}

package() {
  name=$1
  version=$2
  origin=$3
  comment=$4
  stage=$5
  meta="$W/meta-$name"
  rm -rf "$meta"
  mkdir -p "$meta"
  cat > "$meta/+MANIFEST" <<EOF
name: $name
version: "$version"
origin: $origin
comment: $comment
maintainer: trafael@dinx.org
prefix: /usr/local
EOF
  printf '%s\n' "$comment" > "$meta/+DESC"
  # plist paths are absolute install paths; pkg add installs them literally.
  (cd "$stage" && find . -type f | sed 's|^\./|/|') > "$meta/plist"
  pkg create -m "$meta" -p "$meta/plist" -r "$stage" -o "$REPO" >>"$LOG" 2>&1
  log "== pkg create $name exit=$?"
  # pkg create drops shlibs_provided; inject it by repacking with bsdtar.
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
}

if [ ! -d "$W/greetd" ]; then
  git clone --depth 1 https://github.com/kennylevinsen/greetd.git "$W/greetd" >>"$LOG" 2>&1
fi
apply_freebsd_patches
python3 "$W/patch-freebsd.py" "$W" >>"$LOG" 2>&1 || log "== patch-freebsd.py failed"

# --- patched wlroots (Aqueous private dependency) ------------------------
WLR_PREFIX="$W/Aqueous/compositor/.deps/wlroots-render-hook"
stamp wlroots-start
if [ "${DINX_COLD:-0}" = 1 ]; then
  rm -rf "$WLR_PREFIX" "$W/Aqueous/compositor/.zig-cache" "$W/pearl/.zig-cache" "$W/greetd/target"
  log "== COLD rebuild: caches cleared"
fi
if [ ! -f "$WLR_PREFIX/lib/libwlroots-0.20.so" ]; then
  log "== building patched wlroots via upstream script"
  bash "$W/Aqueous/compositor/scripts/build-wlroots-render-hook.sh" >>"$LOG" 2>&1
  log "== patched wlroots exit=$?"
fi
stamp wlroots-end
if [ -f "$WLR_PREFIX/lib/libwlroots-0.20.so" ]; then
  export PKG_CONFIG_PATH="$WLR_PREFIX/libdata/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  # The linker searches -L in order; make the patched lib win over the
  # unpatched system wlroots020 package.
  cp -a "$WLR_PREFIX"/lib/libwlroots-0.20.so* /usr/local/lib/
  stage="$W/stage-dinx-wlroots"
  rm -rf "$stage"; mkdir -p "$stage/usr/local"
  cp -a "$WLR_PREFIX/include" "$WLR_PREFIX/lib" "$WLR_PREFIX/libdata" "$stage/usr/local/"
  [ -d "$WLR_PREFIX/share" ] && cp -a "$WLR_PREFIX/share" "$stage/usr/local/"
  package dinx-wlroots 0.20.2.aqueous dinx/wlroots "wlroots 0.20.2 with Aqueous render/presentation patches" "$stage"
fi
# --- FreeBSD compat lib: Zig-visible shims + the Linux->FreeBSD ABI layer ---
cc -shared -fPIC -O2 -o /usr/local/lib/libdinxcompat.so \
   "$W/dinxcompat.c" "$W/dinxlinux.c" >>"$LOG" 2>&1
log "== dinxcompat exit=$?"
stage="$W/stage-dinx-compat"
rm -rf "$stage"; mkdir -p "$stage/usr/local/lib"
cp /usr/local/lib/libdinxcompat.so "$stage/usr/local/lib/"
package dinx-compat 1.0 dinx/compat "FreeBSD compat shims (statx/mallopt/errno) for Pearl" "$stage"
# --- Aqueous -------------------------------------------------------------
AQ_DIR="$W/Aqueous/compositor"
if [ ! -f "$AQ_DIR/build.zig.zon" ]; then
  AQ_DIR=$(find "$W/Aqueous" -maxdepth 4 -name build.zig.zon 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
fi
stamp aqueous-start
if [ -n "$AQ_DIR" ]; then
  if build_zig aqueous "$AQ_DIR" -Dxwayland=true -Dvulkan-effects=false; then
    stage="$W/stage-dinx-aqueous"
    rm -rf "$stage"; mkdir -p "$stage/usr/local/bin"
    for b in aqueous aqueousctl; do
      [ -f "$AQ_DIR/zig-out/bin/$b" ] && cp "$AQ_DIR/zig-out/bin/$b" "$stage/usr/local/bin/"
    done
    package dinx-aqueous 1.0.5 dinx/aqueous "Aqueous Wayland compositor (Zig/wlroots)" "$stage"
  fi
else
  log "== Aqueous source tree not found"
fi
stamp aqueous-end


stamp pearl-start
# --- Pearl ---------------------------------------------------------------
if [ -d "$W/pearl" ]; then
  if build_zig pearl "$W/pearl"; then
    stage="$W/stage-dinx-pearl"
    rm -rf "$stage"; mkdir -p "$stage/usr/local/bin"
    for b in "$W/pearl/zig-out/bin/"*; do
      [ -f "$b" ] && cp "$b" "$stage/usr/local/bin/"
    done
    package dinx-pearl 0.3.9 dinx/pearl "Pearl desktop shell (Zig/GTK4)" "$stage"
  fi
else
  log "== pearl source tree not found"
fi
stamp pearl-end

stamp greetd-start
# --- greetd --------------------------------------------------------------
if [ -d "$W/greetd" ]; then
  log "== building greetd (cargo)"
  (cd "$W/greetd" && cargo build --release) >>"$LOG" 2>&1
  log "== greetd cargo exit=$?"
  if [ -f "$W/greetd/target/release/greetd" ]; then
    stage="$W/stage-dinx-greetd"
    rm -rf "$stage"; mkdir -p "$stage/usr/local/sbin" "$stage/usr/local/bin"
    cp "$W/greetd/target/release/greetd" "$stage/usr/local/sbin/"
    [ -f "$W/greetd/target/release/agreety" ] && cp "$W/greetd/target/release/agreety" "$stage/usr/local/bin/"
    package dinx-greetd 0.10.3 dinx/greetd "greetd login daemon (built from source)" "$stage"
  fi
fi
stamp greetd-end

stamp kwm-start
# --- kwm (river window manager) ------------------------------------------
# Built from the same pinned revision as distro/bsd/ports/Makefile.kwm, NOT the
# v0.3.0 tag: the tag's build.zig still reads Build.build_root, which Zig 0.17
# removed, so it fails at configure (proven: `zig build --fetch` -> "no field
# named 'build_root'"). kwm links libc, so the porting patches bind
# timerfd/pipe2 straight to FreeBSD libc; see patch-kwm-freebsd.py.
KWM_REV=8dafe7ec636894131521990c2effa3daa09eb205
if [ ! -d "$W/kwm" ]; then
  git clone https://github.com/kewuaa/kwm.git "$W/kwm" >>"$LOG" 2>&1
  git -C "$W/kwm" checkout "$KWM_REV" >>"$LOG" 2>&1
  log "== kwm checked out at $KWM_REV (exit=$?)"
fi
if [ -d "$W/kwm" ]; then
  python3 "$W/patch-kwm-freebsd.py" "$W" >>"$LOG" 2>&1
  log "== patch-kwm-freebsd.py exit=$?"
  # -Dbar=true needs fcft; -Dkwim=true is the input-device helper.
  if build_zig kwm "$W/kwm" -Dbar=true -Dkwim=true; then
    stage="$W/stage-dinx-kwm"
    rm -rf "$stage"; mkdir -p "$stage/usr/local/bin" "$stage/usr/local/etc/xdg/kwm"
    for b in kwm kwim; do
      [ -f "$W/kwm/zig-out/bin/$b" ] && cp "$W/kwm/zig-out/bin/$b" "$stage/usr/local/bin/"
    done
    [ -f "$W/kwm/config.def.zon" ] && cp "$W/kwm/config.def.zon" "$stage/usr/local/etc/xdg/kwm/config.zon"
    package dinx-kwm 0.3.0 dinx/kwm "kwm tiling window manager for the river compositor" "$stage"
  fi
else
  log "== kwm source tree not found"
fi
stamp kwm-end

stamp kwim-start
# --- kwim (river input manager) ------------------------------------------
# Separate upstream (kewuaa/kwim), NOT built by kwm. The v0.2.0 tag still
# reads Build.build_root (removed in Zig 0.17); commit a802d2d ("Update for
# Zig 0.17", minimum_zig_version 0.17.0) builds clean on FreeBSD with no
# patch. Verified: build_rc=0, ldd clean, sole Linux-ism is memfd_create
# which FreeBSD libc has had since 13.
KWIM_REV=a802d2d021e13709b2c130088510bfef5e902659
if [ ! -d "$W/kwim" ]; then
  git clone https://github.com/kewuaa/kwim.git "$W/kwim" >>"$LOG" 2>&1
  git -C "$W/kwim" checkout "$KWIM_REV" >>"$LOG" 2>&1
  log "== kwim checked out at $KWIM_REV (exit=$?)"
fi
if [ -d "$W/kwim" ]; then
  if build_zig kwim "$W/kwim"; then
    stage="$W/stage-dinx-kwim"
    rm -rf "$stage"; mkdir -p "$stage/usr/local/bin"
    [ -f "$W/kwim/zig-out/bin/kwim" ] && cp "$W/kwim/zig-out/bin/kwim" "$stage/usr/local/bin/"
    package dinx-kwim 0.2.0 dinx/kwim "kwim input manager for the river compositor" "$stage"
  fi
else
  log "== kwim source tree not found"
fi
stamp kwim-end

stamp river-shifttags-start
# --- river-shifttags (tag CLI the river shell shells out to) -------------
# Upstream Makefile uses GNU pattern rules bmake cannot parse, links -lrt
# (folded into libc here) and -lpixman-1 (zero pixman symbols in the source).
# Generate the two vendored protocols with wayland-scanner and link only
# wayland-client -- this is what compiled and ran in the build VM.
# Pinned to the exact upstream commit (date 2026-03-22), not floating master, so
# the build is reproducible. The GitHub archive of a SHA extracts to
# river-shifttags-<sha>.
RST_REV=76076b83b6a66245cc02467924692d2b6f40fdbe
if [ ! -d "$W/river-shifttags" ]; then
  fetch -q -o "$W/river-shifttags.tar.gz" \
    "https://github.com/gnuunixchad/river-shifttags/archive/${RST_REV}.tar.gz" >>"$LOG" 2>&1
  tar -xzf "$W/river-shifttags.tar.gz" -C "$W" >>"$LOG" 2>&1
  mv "$W/river-shifttags-${RST_REV}" "$W/river-shifttags" 2>>"$LOG"
fi
if [ -d "$W/river-shifttags" ]; then
  ( cd "$W/river-shifttags" || exit 1
    for p in river-status-unstable-v1 river-control-unstable-v1; do
      wayland-scanner private-code "$p.xml" "$p.c" && \
        wayland-scanner client-header "$p.xml" "$p.h"
    done
    cc -O2 $(pkg-config --cflags wayland-client) -I. \
      -o river-shifttags river-shifttags.c \
      river-status-unstable-v1.c river-control-unstable-v1.c \
      $(pkg-config --libs wayland-client) ) >>"$LOG" 2>&1
  log "== river-shifttags cc exit=$?"
  if [ -x "$W/river-shifttags/river-shifttags" ]; then
    stage="$W/stage-dinx-river-shifttags"
    rm -rf "$stage"; mkdir -p "$stage/usr/local/bin" "$stage/usr/local/share/man/man1"
    cp "$W/river-shifttags/river-shifttags" "$stage/usr/local/bin/"
    [ -f "$W/river-shifttags/river-shifttags.1" ] && \
      cp "$W/river-shifttags/river-shifttags.1" "$stage/usr/local/share/man/man1/"
    package dinx-river-shifttags 20260322 dinx/river-shifttags "river tag-shifting CLI for the river shell" "$stage"
  fi
else
  log "== river-shifttags source tree not found"
fi
stamp river-shifttags-end

pkg repo "$REPO" >>"$LOG" 2>&1
log "== pkg repo exit=$?"
stamp end
log "== DONE"
ls -la "$REPO" | tee -a "$LOG"
