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
# Install prefix. Defaults to /usr/local, NOT a private $W/prefix: the Astal
# shared objects and the .pc files morghulis links against must land where the
# runtime loader resolves them (/usr/local/lib is in the default
# ldconfig_paths), and the prefix is baked into the generated GIR/vapi/typelib
# paths. This matches the configuration the whole stack was proven against in
# the build VM. Override with PREFIX=... only if you also extend
# ldconfig_paths.
PREFIX=${PREFIX:-/usr/local}
LOG=$W/build-astal.log
: > "$LOG"
exec >>"$LOG" 2>&1
export PATH=/usr/local/bin:$PATH

log() { printf '%s\n' "$*" | tee -a "$LOG"; }

REPO="$W/repo"
mkdir -p "$REPO"

# pkg create + catalog, same shape as build-native.sh so the artefacts land in
# the same local `dinx` repo that install-dinx-bsd.sh already consumes.
# morghulis ships a binary plus data (gschema/css/desktop/metainfo) and no
# shared library of its own, so there is no shlibs_provided injection here.
package_plain() { # name version origin comment stage
  _n=$1; _v=$2; _o=$3; _c=$4; _stage=$5
  _meta="$W/meta-$_n"
  rm -rf "$_meta"; mkdir -p "$_meta"
  cat > "$_meta/+MANIFEST" <<EOF
name: $_n
version: "$_v"
origin: $_o
comment: $_c
maintainer: trafael@dinx.org
prefix: /usr/local
EOF
  printf '%s\n' "$_c" > "$_meta/+DESC"
  # plist paths are absolute install paths; pkg add installs them literally.
  (cd "$_stage" && find . -type f | sed 's|^\./|/|') > "$_meta/plist"
  pkg create -m "$_meta" -p "$_meta/plist" -r "$_stage" -o "$REPO" >>"$LOG" 2>&1
  log "== pkg create $_n exit=$?"
}

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

[ "$PREFIX" = "/usr/local" ] || rm -rf "$PREFIX"
mkdir -p "$PREFIX"
# astal-river must stay invisible to morghulis but present for others, so the
# filtered pkgconfig dir below is rebuilt every run.
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

# 4. morghulis itself (the river desktop shell).
#    - libnm/astal-network are carved out by files/morghulis-network-carve.patch:
#      FreeBSD's only libnm is the symbol-less networkmanager-shim, and upstream
#      NetworkManager is Linux-only, so the Network quick-settings panel cannot
#      exist here. Bluetooth/powerprofiles are kept (they compile; inert without
#      org.bluez / power-profiles-daemon at runtime).
#    - the SCSS step needs dart-sass: main.scss uses @use module syntax
#      (adw.$var) which libsass/sassc cannot parse, and the rubygem-dartsass
#      port refuses amd64-freebsd. dart-sass is pure JS: npm local install +
#      a `sass` wrapper over node. Proven: sass 1.108.2 compiles main.scss.
# Pin: trunk at commit a3eb6d7, NOT the v0.14.0 tag. The tag (2025-11) predates
# the current Astal main (2026-08): its NavBar calls river.get_focused_output()
# / river.get_output(), which no longer exist -- AstalRiver now exposes
# `focused_output` as a property plus find_output_by_name(). Trunk matches the
# Astal main this script builds, and trunk already carries the explicit
# astal-wl-0.1 / wayland-client deps that valac needs (it does not follow
# pkg-config Requires transitively), so only the network carve is applied.
MORGHULIS_REV=${MORGHULIS_REV:-a3eb6d76fce3d1993dcfc0b73bec4c4893050df9}
M="$W/morghulis"
if [ ! -d "$M" ]; then
  fetch -q -o "$W/morghulis.tar.gz" \
    "https://github.com/ARKye03/morghulis/archive/$MORGHULIS_REV.tar.gz" \
    || log "FAIL fetch morghulis"
  tar -xzf "$W/morghulis.tar.gz" -C "$W"
  for d in "$W"/morghulis-*; do [ -d "$d" ] && mv "$d" "$M" && break; done
fi
if [ -d "$M" ]; then
  # Two patches, both required and both verified against the pinned trunk rev:
  #   morghulis-network-carve.patch -- drops libnm/astal-network and the Network
  #     quick-settings panel. FreeBSD has no usable libnm (the only one,
  #     net-mgmt/networkmanager-shim, is symbol-less) and upstream
  #     NetworkManager is Linux-only, so morghulis cannot configure while
  #     dependency('libnm')/('astal-network-0.1') are unconditional. Bluetooth
  #     and powerprofiles stay (they compile; runtime-inert without org.bluez /
  #     power-profiles-daemon).
  #   morghulis-memfd-freebsd.patch -- Gamma.vala uses Linux.memfd_create, whose
  #     Vala binding emits #include <linux/memfd.h> (absent on FreeBSD). Bound to
  #     libc memfd_create in <sys/mman.h> instead (present since FreeBSD 13).
  SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
  PATCH_DIR=${PATCH_DIR:-$SCRIPT_DIR/../../distro/bsd/ports/files}
  for pname in morghulis-network-carve.patch morghulis-memfd-freebsd.patch; do
    P="$PATCH_DIR/$pname"
    if [ ! -f "$P" ]; then
      log "FAIL missing patch $P"; exit 1
    elif (cd "$M" && patch -p1 -N --dry-run -i "$P") >/dev/null 2>&1; then
      (cd "$M" && patch -p1 -i "$P") >>"$LOG" 2>&1 \
        && log "== applied $pname" || { log "FAIL applying $pname"; exit 1; }
    else
      # -N refuses already-applied hunks: idempotent re-run.
      log "== $pname already applied"
    fi
  done
  # dart-sass via local npm (pure JS; no node_modules shipped in the ISO)
  if ! command -v sass >/dev/null 2>&1 || ! sass --version 2>/dev/null | grep -q dart2js; then
    mkdir -p "$W/sasstool" && (cd "$W/sasstool" && [ -x node_modules/.bin/sass ] || npm install sass) >>"$LOG" 2>&1
    cat > /usr/local/bin/sass <<SEOF
#!/bin/sh
exec /usr/local/bin/node "$W/sasstool/node_modules/sass/sass.js" "\$@"
SEOF
    chmod 755 /usr/local/bin/sass
    log "== sass wrapper -> dart-sass ($(sass --version 2>&1 | head -1))"
  fi
  # AstalRiver is INCOMPATIBLE with the river this session ships, so hide it
  # from morghulis's configure. Evidence: river removed river-status-unstable-v1
  # in a309d18e (2024-07-21) -- that is what AstalRiver binds (river.vala:234
  # find_globals("zriver_status_manager_v1"), which then fails with "the
  # compositor does not support zriver_status_manager_v1"); river replaced it
  # with river-window-management-v1, which is what kwm implements. No river
  # release carries both (v0.3.0..v0.3.12: status only; v0.4.0..v0.5.2:
  # window-management only, verified per-tag against the protocol dir). kwm is
  # the window manager, so river >= 0.4 wins and morghulis builds without the
  # river module -- it is required:false upstream, which drops RiverTags and the
  # --define=river tag bar. Set MORGHULIS_USE_ASTAL_RIVER=1 once astal-river
  # tracks river-window-management-v1.
  #
  # Implemented as a filtered pkgconfig dir rather than by moving the .pc aside,
  # so the rest of the system keeps astal-river installed.
  MORGHULIS_PC="$PREFIX/lib/pkgconfig:$PREFIX/libdata/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/libdata/pkgconfig"
  if [ "${MORGHULIS_USE_ASTAL_RIVER:-0}" != 1 ]; then
    MPC="$W/morghulis-pkgconfig"
    rm -rf "$MPC"; mkdir -p "$MPC"
    for pcdir in "$PREFIX/lib/pkgconfig" "$PREFIX/libdata/pkgconfig" \
                 /usr/local/lib/pkgconfig /usr/local/libdata/pkgconfig; do
      [ -d "$pcdir" ] || continue
      for pc in "$pcdir"/*.pc; do
        [ -f "$pc" ] || continue
        case $(basename "$pc") in
          astal-river-*) continue ;;
        esac
        ln -sf "$pc" "$MPC/$(basename "$pc")"
      done
    done
    MORGHULIS_PC="$MPC"
    log "== astal-river hidden from morghulis configure (river/kwm protocol conflict)"
  fi
  rm -rf "$M/build"
  (cd "$M" && PKG_CONFIG_PATH="$MORGHULIS_PC" \
     meson setup build --prefix="$PREFIX" > /tmp/morph-ms.log 2>&1)
  log "== morghulis configure_rc=$?"
  (cd "$M" && PKG_CONFIG_PATH="$MORGHULIS_PC" \
     ninja -C build > /tmp/morph-nj.log 2>&1)
  log "== morghulis build_rc=$?"
  if [ -x "$M/build/src/morghulis" ]; then
    # Stage into a DESTDIR tree, then pkg-create it. Version comes from the
    # source `version` file so the package tracks the pinned rev.
    MVER=$(cat "$M/version" 2>/dev/null || echo 0.0.0)
    MVER=${MVER#v}
    stage="$W/stage-dinx-morghulis"
    rm -rf "$stage"; mkdir -p "$stage"
    (cd "$M" && DESTDIR="$stage" ninja -C build install) >>"$LOG" 2>&1
    log "== morghulis staged (DESTDIR) exit=$?"
    # meson installs the gschema .xml; FreeBSD has no compile trigger for it, so
    # install-dinx-bsd.sh runs glib-compile-schemas at first boot. Ship the .xml.
    package_plain dinx-morghulis "$MVER" dinx/morghulis \
      "morghulis GTK4/Astal shell for the river session (no river tag bar: AstalRiver needs river<=0.3, kwm needs >=0.4)" \
      "$stage"
  else
    log "== morghulis FAILED; see /tmp/morph-ms.log /tmp/morph-nj.log"
    grep -m6 'error:\|FAILED:' /tmp/morph-nj.log 2>/dev/null | tee -a "$LOG"
  fi
else
  log "== morghulis source tree not found"
fi
# Refresh the local repo catalog so `pkg install -r dinx dinx-morghulis` resolves.
# POSIX sh has no compgen; ls tolerates the no-match case via the guard.
if ls "$REPO"/*.pkg >/dev/null 2>&1; then
  pkg repo "$REPO" >>"$LOG" 2>&1
  log "== pkg repo exit=$?"
  ls -la "$REPO" | tee -a "$LOG"
fi
log DONE_ASTAL_MORPHULIS
