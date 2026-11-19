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
# the same local `dinx` repo that install-dinx-bsd.sh already consumes, with
# shlibs_provided injected (pkg create drops it, which makes `pkg add` fail with
# "Missing shlib" once anything links these .so files).
package() { # name version origin comment stage [deps_ucl]
  _n=$1; _v=$2; _o=$3; _c=$4; _stage=$5; _deps=${6:-}
  _meta="$W/meta-$_n"
  rm -rf "$_meta"; mkdir -p "$_meta"
  # The comment MUST be quoted: pkg's UCL parser terminates an unquoted value at
  # a comma, so any comment containing one was silently truncated. Observed in
  # the integrated run: glycin's stored comment came out as
  # "glycin image loader (morghulis hard dep" -- everything after the comma,
  # including the closing paren, was dropped.
  {
    printf 'name: %s\n' "$_n"
    printf 'version: "%s"\n' "$_v"
    printf 'origin: %s\n' "$_o"
    printf 'comment: "%s"\n' "$_c"
    printf 'maintainer: trafael@dinx.org\n'
    printf 'prefix: /usr/local\n'
    if [ -n "$_deps" ]; then
      printf 'deps: {\n'
      printf '  %s\n' "$_deps"
      printf '}\n'
    fi
  } > "$_meta/+MANIFEST"
  printf '%s\n' "$_c" > "$_meta/+DESC"
  # plist paths are absolute install paths; pkg add installs them literally.
  (cd "$_stage" && find . -type f -o -type l | sed 's|^\./|/|') > "$_meta/plist"
  pkg create -m "$_meta" -p "$_meta/plist" -r "$_stage" -o "$REPO" >>"$LOG" 2>&1
  log "== pkg create $_n exit=$?"
  _prov=$(sed -n 's|^/usr/local/lib/\(lib[^/]*\.so[^/]*\)$|\1|p' "$_meta/plist" \
    | sed 's/.*/"&"/' | paste -sd, -)
  if [ -n "$_prov" ] && [ -f "$REPO/$_n-$_v.pkg" ]; then
    rm -rf "$_meta/inject"; mkdir -p "$_meta/inject"
    tar -xf "$REPO/$_n-$_v.pkg" -C "$_meta/inject" >>"$LOG" 2>&1
    python3 - "$_meta/inject" "[$_prov]" >>"$LOG" 2>&1 <<'PY'
import json, os, sys
d, prov = sys.argv[1], json.loads(sys.argv[2])
for nm in ("+MANIFEST", "+COMPACT_MANIFEST"):
    p = os.path.join(d, nm)
    if os.path.exists(p):
        m = json.load(open(p))
        m["shlibs_provided"] = prov
        json.dump(m, open(p, "w"), separators=(",", ":"))
PY
    (cd "$_meta/inject" && tar -P -cf "$REPO/$_n-$_v.pkg" -s '|^usr|/usr|' \
      +COMPACT_MANIFEST +MANIFEST usr) >>"$LOG" 2>&1
    log "== shlibs_provided injected into $_n exit=$?"
  fi
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

# Each module is installed twice: once into the live $PREFIX so downstream
# modules resolve their deps at configure/link time, and once into a DESTDIR
# staging tree (layout $stage$PREFIX/...) that is pkg-created so the artefact is
# installable on a clean target. pkgname = the .pc/library base name.
build_mod() { # dir pkgname version  (dir relative to $ASTAL/lib)
  mod=$1; pkgname=$2; ver=${3:-0.1.0}
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
  # stage for packaging
  if [ -n "$pkgname" ]; then
    stage="$W/stage-$pkgname"; rm -rf "$stage"; mkdir -p "$stage"
    (cd "$d" && DESTDIR="$stage" ninja -C build install >/tmp/astal-stage.log 2>&1) || {
      log "FAIL stage $mod"; return 1; }
    # meson's DESTDIR layout is $stage$PREFIX/... ; pkg create wants the stage
    # root that contains usr/local/... so the plist paths become /usr/local/...
    package "$pkgname" "$ver" "dinx/$pkgname" "Astal $mod (FreeBSD build)" "$stage"
  fi
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
  # stage + package the translator so lib/tray's dep is installable on target
  tstage="$W/stage-appmenu-glib-translator"; rm -rf "$tstage"; mkdir -p "$tstage"
  (cd "$T" && DESTDIR="$tstage" ninja -C build install >/tmp/amt-stage.log 2>&1) \
    && package appmenu-glib-translator 26.11 dinx/appmenu-glib-translator \
         "appmenu-glib-translator (Astal tray dependency, FreeBSD ulong fix)" "$tstage" \
    || log "FAIL stage/package translator"
  # the mirrored header subdir lives only in the live PREFIX; recreate it in the
  # stage so the package is self-consistent for downstream builds.
  for d in exporter importer; do
    if [ -f "$tstage$PREFIX/include/appmenu-glib-translator/$d.h" ]; then
      mkdir -p "$tstage$PREFIX/include/appmenu-glib-translator/$d"
      ln -sf "../$d.h" "$tstage$PREFIX/include/appmenu-glib-translator/$d/$d.h"
    fi
  done
else
  log "FAIL translator: no tree"; exit 1
fi

# 2. astal modules in dependency order. tray is last: it needs translator.
#    Format: dir:pkgname:version (pkgname matches the installed .so/.pc base).
ok=0; fail=0
for entry in \
  "quarrel:quarrel:0.1.0" \
  "astal/io:astal-io:0.1.0" \
  "wl/wl:astal-wl:0.1.0" \
  "astal/gtk4:astal-4:4.0" \
  "river:astal-river:0.1.0" \
  "notifd:astal-notifd:0.1.0" \
  "mpris:astal-mpris:0.1.0" \
  "brightness:astal-brightness:0.1.0" \
  "workspace:astal-workspace:0.1.0" \
  "idle-notify:astal-idle-notify:0.1.0" \
  "apps:astal-apps:0.1.0" \
  "battery:astal-battery:0.1.0" \
  "bluetooth:astal-bluetooth:0.1.0" \
  "powerprofiles:astal-power-profiles:0.1.0" \
  "wireplumber:astal-wireplumber:0.1.0" \
  "tray:astal-tray:0.1.0"; do
  d=${entry%%:*}; rest=${entry#*:}; pn=${rest%%:*}; ver=${rest##*:}
  if build_mod "$d" "$pn" "$ver"; then ok=$((ok+1)); else fail=$((fail+1)); fi
done
log "== astal modules: ok=$ok fail=$fail"

# 3. typelib sanity: morghulis imports these namespaces at runtime.
for t in Astal-4.0 AstalIO-0.1 AstalWl-0.1 AstalRiver-0.1 AstalNotifd-0.1 AstalMpris-0.1 AstalTray-0.1 AstalApps-0.1 AstalBattery-0.1 AstalWp-0.1; do
  f=$(find "$PREFIX" -name "$t.typelib" 2>/dev/null | head -1)
  [ -n "$f" ] && log "typelib $t: $(basename "$f")" || log "typelib $t: ABSENT"
done

log "== staging summary =="
ls "$PREFIX/lib"/*.so* 2>/dev/null | head -20

# 3b. glycin: morghulis hard-depends glycin-2 + glycin-gtk4-2 (image loading),
#     which the FreeBSD catalogue does not ship. glycin's own meson disables its
#     Linux sandbox loaders off-Linux (host_machine.system()=='linux') and embeds
#     them instead, so it is portable by design. It needs rust (catalogue has it).
#     Verified: configure_rc=0, build_rc=0, install_rc=0 -> glycin-2.pc +
#     glycin-gtk4-2.pc. The first build is slow (~minutes, rust); the earlier
#     "FAIL" I hit was my own ninja timeout, not a compile error.
#
#     Always build from our own source tree and always pkg-create it. Do NOT
#     gate on `pkg-config --exists glycin-2`: a glycin already installed in the
#     build VM (e.g. from an earlier manual run) would make that true and skip
#     packaging, leaving the dinx repo without the glycin .pkg that a clean
#     target needs. The guard conflates "system has it" with "repo has it".
GLY=${GLYCIN_REV:-main}
[ -d "$W/glycin" ] || {
  fetch -q -o "$W/glycin.tar.gz" \
    "https://gitlab.gnome.org/GNOME/glycin/-/archive/$GLY/glycin-$GLY.tar.gz" || { log "FAIL fetch glycin"; }
  tar -xzf "$W/glycin.tar.gz" -C "$W" && mv "$W/glycin-$GLY" "$W/glycin" 2>/dev/null
}
if [ -d "$W/glycin" ]; then
  command -v rustc >/dev/null 2>&1 || pkg install -y rust >/dev/null 2>&1
  if [ "${REBUILD_GLYCIN:-0}" = 1 ] || [ ! -d "$W/glycin/build" ]; then
    log "== building glycin (rust=$(rustc --version 2>/dev/null | head -1))"
    rm -rf "$W/glycin/build"
    (cd "$W/glycin" && meson setup build --prefix="$PREFIX" >/tmp/gly-ms.log 2>&1) \
      && log "== glycin configure=ok" || log "FAIL glycin configure: $(grep -m1 ERROR /tmp/gly-ms.log)"
    if [ -d "$W/glycin/build" ]; then
      (cd "$W/glycin" && ninja -C build >/tmp/gly-nj.log 2>&1) \
        && log "== glycin build=ok" || { log "FAIL glycin build"; grep -m4 'error' /tmp/gly-nj.log | tee -a "$LOG"; }
      (cd "$W/glycin" && ninja -C build install >>"$LOG" 2>&1) && log "== glycin install=ok"
    fi
  else
    log "== glycin build dir present; reusing (set REBUILD_GLYCIN=1 to rebuild)"
  fi
  if [ -d "$W/glycin/build" ]; then
    # Stage + package regardless of whether we just built or reused, so the
    # dinx repo always carries the glycin .pkg.
    gstage="$W/stage-glycin"; rm -rf "$gstage"; mkdir -p "$gstage"
    (cd "$W/glycin" && DESTDIR="$gstage" ninja -C build install >/tmp/gly-stage.log 2>&1) \
      && package glycin 2.3.0 dinx/glycin "glycin image loader; sandbox loaders embedded off-Linux" "$gstage" \
      || log "FAIL stage/package glycin"
  fi
else
  log "== glycin source tree not found"
fi

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
  for pname in morghulis-network-carve.patch morghulis-memfd-freebsd.patch morghulis-kwm-tags.patch; do
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
    # glycin must be an EXPLICIT dep. Unlike every other library morghulis links,
    # glycin's .so files carry no DT_SONAME, so the linker recorded them as
    # absolute-path DT_NEEDED entries (/usr/local/lib/libglycin-2.so and
    # libglycin-gtk4-2.so). pkg's shlibs mechanism keys on SONAME and cannot
    # see them: readelf shows 29 DT_NEEDED on morghulis while shlibs_required has
    # 27 -- the two missing ones are exactly those glycin libs. Without this
    # dep a clean target installs a morghulis that fails at load time, and the
    # `pkg install -n` plan confirms glycin is not pulled automatically.
    package dinx-morghulis "$MVER" dinx/morghulis \
      "morghulis GTK4/Astal shell for the river session (no river tag bar: AstalRiver needs river<=0.3; kwm needs >=0.4)" \
      "$stage" \
      'glycin: { origin: dinx/glycin, version: "2.3.0" }'
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
