#!/bin/sh
# Native FreeBSD build of the river-desktop upper stack: appmenu-glib-translator,
# the Astal 0.1 modules morghulis needs, then morghulis itself. Run INSIDE the
# FreeBSD build VM as root: sh build-astal-morghulis.sh [workdir]
#
# Why this exists: morghulis is the desktop shell for the river session
# (river + kwm + kwim are already ported; see patch-kwm-freebsd.py), and the
# FreeBSD 15.1 catalogue ships no astal, no appmenu-glib-translator and no
# sassc. All three are buildable from source; this script does the build,
# staging and pkg-create, and it refuses to ship a module it could not build.
#
# Two things are patched, both FreeBSD-only and both upstream-neutral:
#   - every Astal module generates its GIR by running gir.py, which shells out
#     to valadoc; lang/vala is configured --disable-valadoc on FreeBSD. gir.py
#     honours $VALADOC, so the shim (files/astal-valadoc-shim) re-implements
#     the GIR emission with `valac -C --library` -- same GIR structure, minus
#     doc comments, which only gi-docgen HTML consumes.
#   - appmenu-glib-translator's importer uses ulong, which is not in FreeBSD's
#     sys/types.h; one sed to gulong.
#
# Modules are built in dependency order into a private prefix so a failed
# upper module cannot silently fall back on a system copy of a lower one:
#   quarrel -> astal/io -> wl/wl -> astal/gtk4 -> {river, notifd, mpris,
#   brightness, workspace, idle-notify, apps, battery, bluetooth,
#   powerprofiles} -> translator -> tray. lib/network (needs libnm, which
#   FreeBSD does not have outside the symbol-less networkmanager-shim) and
#   lib/auth (needs OpenPAM .pc; base headers are in the -dev dist) are NOT
#   built here -- see NOTES at the end of this file.
set -u
W=${1:-/root/astal}
PREFIX=$W/prefix
LOG=$W/build-astal.log
: > "$LOG"
exec >>"$LOG" 2>&1
export PATH=/usr/local/bin:$PATH

log() { printf '%s\n' "$*" | tee -a "$LOG"; }

[ -d "$W/astal-main" ] || {
  mkdir -p "$W"
  fetch -q -o "$W/astal.tar.gz" https://github.com/Aylur/astal/archive/refs/heads/main.tar.gz || { log "FETCH_FAIL astal"; exit 1; }
  sha256 -q "$W/astal.tar.gz" > "$W/astal.sha256"
  tar -xzf "$W/astal.tar.gz" -C "$W"
}
ASTAL=$W/astal-main
[ -d "$ASTAL/lib/astal/io" ] || { log "NO ASTAL TREE"; exit 1; }

# valadoc shim, from this repo.
SHIM_SRC=${SHIM_SRC:-}
[ -n "$SHIM_SRC" ] && [ -f "$SHIM_SRC" ] && install -m 0755 "$SHIM_SRC" /usr/local/bin/astal-valadoc-shim || true
[ -x /usr/local/bin/astal-valadoc-shim ] || { log "MISSING /usr/local/bin/astal-valadoc-shim (set SHIM_SRC)"; exit 1; }
export VALADOC=/usr/local/bin/astal-valadoc-shim

rm -rf "$PREFIX"; mkdir -p "$PREFIX"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/libdata/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/libdata/pkgconfig"

build_mod() { # dir  (relative to $ASTAL/lib)
  mod=$1
  d=$ASTAL/lib/$mod
  [ -d "$d" ] || { log "SKIP $mod (no dir)"; return 1; }
  rm -rf "$d/build"
  log "== configuring $mod"
  (cd "$d" && meson setup build --prefix="$PREFIX" >/tmp/astal-ms.log 2>&1) || {
    log "FAIL configure $mod: $(grep -m1 ERROR /tmp/astal-ms.log)"; return 1; }
  log "== building $mod"
  (cd "$d" && ninja -C build >/tmp/astal-nj.log 2>&1) || {
    log "FAIL build $mod: $(grep -m1 'error:' /tmp/astal-nj.log)"; return 1; }
  (cd "$d" && ninja -C build install >>/tmp/astal-in.log 2>&1) || { log "FAIL install $mod"; return 1; }
  log "OK $mod"
}

# 1. translator (tray's only blocker) with the ulong fix.
[ -d "$W/vpa/subprojects/appmenu-glib-translator" ] || {
  fetch -q -o "$W/vpa.tar.gz" "https://gitlab.com/vala-panel-project/vala-panel-appmenu/-/archive/master/vala-panel-appmenu-master.tar.gz" \
    && mkdir -p "$W/vpa" && tar -xzf "$W/vpa.tar.gz" -C "$W/vpa" --strip-components 1
}
T=$W/vpa/subprojects/appmenu-glib-translator
if [ -d "$T" ]; then
  # ulong is not a type in FreeBSD's <sys/types.h>; the translator's importer
  # and exporter declare `ulong name_id`. BSD sed has no \b, so match the
  # word boundary with [[:<:]]/[[:>:]] (proven: plain `s/ulong/gulong/g` also
  # works here because every occurrence is the type, not a substring).
  for f in "$T/importer/importer.c" "$T/exporter/exporter.c"; do
    [ -f "$f" ] && sed -i '' 's/[[:<:]]ulong[[:>:]]/gulong/g' "$f"
  done
  rm -rf "$T/build"
  (cd "$T" && meson setup build --prefix="$PREFIX" >/tmp/amt-ms.log 2>&1 \
     && ninja -C build >/tmp/amt-nj.log 2>&1 && ninja -C build install >>/tmp/amt-in.log 2>&1) \
    && log "OK translator" || { log "FAIL translator: $(grep -m1 'error:' /tmp/amt-nj.log)"; exit 1; }
  # The translator's Vala binding emits #include <exporter/exporter.h> and
  # <importer/importer.h>, but its install_headers drops them FLAT under
  # include/appmenu-glib-translator/. Without the subdir layout lib/tray dies
  # with "fatal error: 'exporter/exporter.h' file not found". Mirror them.
  H="$PREFIX/include/appmenu-glib-translator"
  for d in exporter importer; do
    [ -f "$H/$d.h" ] && { mkdir -p "$H/$d"; ln -sf "$H/$d.h" "$H/$d/$d.h"; }
  done
else
  log "FAIL translator: no tree"; exit 1
fi

# 2. astal modules in dependency order. tray is last: it needs translator.
ok=0; fail=0
for m in quarrel astal/io wl/wl astal/gtk4 river notifd mpris brightness workspace idle-notify apps battery bluetooth powerprofiles tray; do
  if build_mod "$m"; then ok=$((ok+1)); else fail=$((fail+1)); fi
done
log "== astal modules: ok=$ok fail=$fail"

# 3. typelib sanity: morghulis imports these namespaces at runtime.
for t in Astal-4.0 AstalIO-0.1 AstalWl-0.1 AstalRiver-0.1 AstalNotifd-0.1 AstalMpris-0.1 AstalTray-0.1 AstalApps-0.1 AstalBattery-0.1 AstalWp-0.1; do
  f=$(find "$PREFIX" -name "$t.typelib" 2>/dev/null | head -1)
  [ -n "$f" ] && log "typelib $t: $(basename "$f")" || log "typelib $t: ABSENT"
done

log "== staging summary =="
ls "$PREFIX/lib"/*.so* 2>/dev/null | head -20
log DONE_ASTAL_MORGHULIS
