#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 DINX Contributors
# SPDX-License-Identifier: Apache-2.0
#
# EuroOffice lean repack pipeline.
#
# Imports the upstream Euro-Office DesktopEditors amd64 deb, debloats it
# (dictionary/locale trim, regenerable cache removal), strips ELF objects,
# reorganizes the tree under /opt/eurooffice, and emits two artifacts:
#
#   eurooffice-<ver>-<pkgrel>-x86_64.pkg.tar.zst  pacman package (install/rootfs)
#   eurooffice-<ver>-x86_64.squashfs              xz/1MiB/BCJ image (live)
#
# plus SHA256SUMS and build-metadata.json. Runs unprivileged; needs:
# curl, jq, ar, tar (xz+zstd), strip, mksquashfs, unsquashfs, sha256sum.
#
# Environment:
#   EUROFFICE_VERSION      upstream version without leading v (default: latest release)
#   EUROFFICE_DEB          optional path to an already-downloaded deb
#   EUROFFICE_PKREL        DINX pkgrel (default 1)
#   EUROFFICE_OUTDIR       artifact directory (default dist/office/eurooffice)
#   EUROFFICE_WORKDIR      scratch directory (default: mktemp)
#   EUROFFICE_KEEP_DICTS   dictionaries to keep (default "en_US en_GB pt_BR")
#   EUROFFICE_KEEP_LOCALES CEF locales to keep (default "en-US en-GB pt-BR")
#   EUROFFICE_KEEP_TEMPLATES template gallery languages (default "EN PT")
#   EUROFFICE_NO_STRIP     set to 1 to skip ELF stripping
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
upstream_repo=${EUROFFICE_UPSTREAM_REPO:-Euro-Office/DesktopEditors}
pkgrel=${EUROFFICE_PKREL:-1}
outdir=${EUROFFICE_OUTDIR:-dist/office/eurooffice}
keep_dicts=${EUROFFICE_KEEP_DICTS:-en_US en_GB pt_BR}
keep_locales=${EUROFFICE_KEEP_LOCALES:-en-US en-GB pt-BR}
keep_templates=${EUROFFICE_KEEP_TEMPLATES:-EN PT}
no_strip=${EUROFFICE_NO_STRIP:-0}

for tool in curl jq ar tar strip mksquashfs unsquashfs sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'build: missing required tool: %s\n' "$tool" >&2; exit 1; }
done
[[ "$pkgrel" =~ ^[1-9][0-9]*$ ]] || { printf 'build: invalid EUROFFICE_PKREL: %s\n' "$pkgrel" >&2; exit 1; }

workdir=${EUROFFICE_WORKDIR:-$(mktemp -d /tmp/eurooffice-build.XXXXXX)}
mkdir -p "$workdir" "$outdir"
outdir=$(cd -- "$outdir" && pwd)
tree="$workdir/tree"          # extracted upstream payload
pkgroot="$workdir/pkgroot"    # reorganized DINX install tree
mkdir -p "$tree" "$pkgroot"

log() { printf 'eurooffice-build: %s\n' "$*"; }

# --- 1. Resolve upstream release and deb asset ------------------------------
version=${EUROFFICE_VERSION:-}
deb_url=${EUROFFICE_DEB_URL:-}
asset_name=''
if [[ -z "$version" || -z "$deb_url" ]]; then
  if [[ -n "$version" ]]; then
    release_json=$(curl -fsSL "https://api.github.com/repos/$upstream_repo/releases/tags/v$version")
  else
    release_json=$(curl -fsSL "https://api.github.com/repos/$upstream_repo/releases/latest")
  fi
  tag=$(jq -r '.tag_name' <<<"$release_json")
  [[ "$tag" =~ ^v[0-9]+(\.[0-9]+)+$ ]] || { printf 'build: unexpected upstream tag: %s\n' "$tag" >&2; exit 1; }
  version=${version:-${tag#v}}
  asset_name=$(jq -r --arg v "$version" '.assets[] | select(.name | test("euro-office-euro-office_" + $v + "-[0-9]+_amd64\\.deb$")) | .name' <<<"$release_json" | head -1)
  [[ -n "$asset_name" ]] || { printf 'build: no amd64 deb asset for %s\n' "$tag" >&2; exit 1; }
  deb_url="https://github.com/$upstream_repo/releases/download/$tag/$asset_name"
fi
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { printf 'build: invalid version: %s\n' "$version" >&2; exit 1; }
log "upstream version=$version"

# --- 2. Import upstream deb --------------------------------------------------
deb="$workdir/upstream.deb"
if [[ -n "${EUROFFICE_DEB:-}" ]]; then
  cp -- "$EUROFFICE_DEB" "$deb"
else
  log "downloading $deb_url"
  curl -fsSL --retry 3 -o "$deb" "$deb_url"
fi
deb_sha256=$(sha256sum "$deb" | cut -d' ' -f1)
deb_bytes=$(stat -c '%s' "$deb")
log "deb sha256=$deb_sha256 bytes=$deb_bytes"

data_member=$(ar t "$deb" | grep -E '^data\.tar' | head -1)
[[ -n "$data_member" ]] || { printf 'build: deb has no data.tar member\n' >&2; exit 1; }
case "$data_member" in
  data.tar.xz) ar p "$deb" "$data_member" | tar -xJ -C "$tree" ;;
  data.tar.zst) ar p "$deb" "$data_member" | tar --zstd -x -C "$tree" ;;
  data.tar.gz) ar p "$deb" "$data_member" | tar -xz -C "$tree" ;;
  *) printf 'build: unsupported data member: %s\n' "$data_member" >&2; exit 1 ;;
esac

upstream_root="$tree/opt/euro-office/euro-office"
[[ -x "$upstream_root/DesktopEditors" ]] || { printf 'build: unexpected deb layout (missing DesktopEditors)\n' >&2; exit 1; }
upstream_installed_bytes=$(du -sb "$tree" | cut -f1)

# --- 3. Reorganize into the DINX install tree --------------------------------
mkdir -p "$pkgroot/opt/eurooffice" "$pkgroot/usr/bin" \
  "$pkgroot/usr/share/applications" "$pkgroot/usr/share/licenses/eurooffice" \
  "$pkgroot/usr/share/doc/eurooffice"
cp -a "$upstream_root"/. "$pkgroot/opt/eurooffice/"
# Upstream /usr payload: keep icons/mime/metainfo, drop upstream launchers and
# desktop entries (DINX ships its own identity below).
if [[ -d "$tree/usr/share" ]]; then
  cp -a "$tree/usr/share"/. "$pkgroot/usr/share/"
fi
find "$pkgroot/usr/share/applications" -maxdepth 1 -name '*.desktop' -delete 2>/dev/null || true
rm -rf "$pkgroot/usr/bin"
mkdir -p "$pkgroot/usr/bin"

# --- 4. Debloat ---------------------------------------------------------------
trim_manifest="$workdir/trim-manifest.txt"
: > "$trim_manifest"
removed_bytes=0

record_removal() { # path label
  local bytes
  bytes=$(du -sb -- "$1" | cut -f1)
  removed_bytes=$((removed_bytes + bytes))
  printf '%s\t%s\t%s\n' "$2" "$bytes" "$1" >> "$trim_manifest"
}

# 4a. Dictionaries: keep only the configured languages.
if [[ -d "$pkgroot/opt/eurooffice/dictionaries" ]]; then
  for dict_dir in "$pkgroot/opt/eurooffice/dictionaries"/*/; do
    [[ -d "$dict_dir" ]] || continue
    lang=$(basename -- "$dict_dir")
    keep=0
    for want in $keep_dicts; do [[ "$lang" == "$want" ]] && keep=1; done
    if (( keep == 0 )); then
      record_removal "$dict_dir" dictionary
      rm -rf -- "$dict_dir"
    fi
  done
fi

# 4b. CEF locales: keep only the configured UI locales.
if [[ -d "$pkgroot/opt/eurooffice/locales" ]]; then
  for pak in "$pkgroot/opt/eurooffice/locales"/*.pak; do
    [[ -f "$pak" ]] || continue
    locale=$(basename -- "$pak" .pak)
    keep=0
    for want in $keep_locales; do [[ "$locale" == "$want" ]] && keep=1; done
    if (( keep == 0 )); then
      record_removal "$pak" cef-locale
      rm -f -- "$pak"
    fi
  done
fi

# 4c. Regenerable V8 code caches (rebuilt by the editors at runtime).
while IFS= read -r cache_file; do
  record_removal "$cache_file" sdkjs-cache
  rm -f -- "$cache_file"
done < <(find "$pkgroot/opt/eurooffice" -type f -name '*.cache')

# 4d. Qt development-only payloads (not needed at runtime).
for devel_dir in cmake pkgconfig designer qmllint qmlls qmltooling objects-RelWithDebInfo; do
  if [[ -e "$pkgroot/opt/eurooffice/$devel_dir" ]]; then
    record_removal "$pkgroot/opt/eurooffice/$devel_dir" qt-devel
    rm -rf -- "$pkgroot/opt/eurooffice/$devel_dir"
  fi
done

# 4e. Localized template gallery: keep only the configured languages.
# These are zip-compressed office files, near-incompressible in the ISO.
if [[ -d "$pkgroot/opt/eurooffice/converter/templates" ]]; then
  for tpl_dir in "$pkgroot/opt/eurooffice/converter/templates"/*/; do
    [[ -d "$tpl_dir" ]] || continue
    lang=$(basename -- "$tpl_dir")
    keep=0
    for want in $keep_templates; do [[ "$lang" == "$want" ]] && keep=1; done
    if (( keep == 0 )); then
      record_removal "$tpl_dir" template-gallery
      rm -rf -- "$tpl_dir"
    fi
  done
fi

# 4f. IE/asm.js fallback engines: the desktop editors run on CEF (Chromium)
# and use the WASM/modern paths; *_ie.js and monaco-for-ie are dead weight.
while IFS= read -r ie_file; do
  record_removal "$ie_file" ie-fallback
  rm -f -- "$ie_file"
done < <(find "$pkgroot/opt/eurooffice/editors" -type f -name '*_ie.js')
if [[ -d "$pkgroot/opt/eurooffice/editors/web-apps/vendor/monaco/monaco-for-ie" ]]; then
  record_removal "$pkgroot/opt/eurooffice/editors/web-apps/vendor/monaco/monaco-for-ie" ie-fallback
  rm -rf -- "$pkgroot/opt/eurooffice/editors/web-apps/vendor/monaco/monaco-for-ie"
fi

log "debloat removed $removed_bytes bytes ($(wc -l < "$trim_manifest") entries)"

# --- 5. Strip ELF objects ------------------------------------------------------
stripped=0
strip_failures=0
if [[ "$no_strip" != 1 ]]; then
  while IFS= read -r -d '' candidate; do
    magic=$(head -c 4 -- "$candidate" | od -An -tx1 | tr -d ' \n')
    [[ "$magic" == 7f454c46 ]] || continue
    if strip --strip-unneeded -- "$candidate" 2>/dev/null; then
      stripped=$((stripped + 1))
    else
      strip_failures=$((strip_failures + 1))
      printf 'strip-failed\t%s\n' "$candidate" >> "$trim_manifest"
    fi
  done < <(find "$pkgroot/opt" "$pkgroot/usr" -type f -print0)
  log "stripped=$stripped strip_failures=$strip_failures"
fi

# --- 6. DINX identity: launcher, desktop entry, licenses, provenance ----------
# Launcher: reuse the upstream desktopeditors script (localized template
# helper, LD_LIBRARY_PATH, LD_PRELOAD=libcef.so) with the DINX app path.
upstream_launcher="$tree/usr/bin/desktopeditors"
[[ -f "$upstream_launcher" ]] || { printf 'build: missing upstream launcher (usr/bin/desktopeditors)\n' >&2; exit 1; }
sed 's|/opt/euro-office/euro-office|/opt/eurooffice|g' "$upstream_launcher" > "$pkgroot/usr/bin/eurooffice"
chmod 0755 "$pkgroot/usr/bin/eurooffice"
grep -Fq 'LD_PRELOAD' "$pkgroot/usr/bin/eurooffice" \
  || { printf 'build: launcher lost LD_PRELOAD\n' >&2; exit 1; }
install -Dm644 "$script_dir/assets/eurooffice.desktop" "$pkgroot/usr/share/applications/eurooffice.desktop"
install -Dm644 "$script_dir/assets/LICENSE" "$pkgroot/usr/share/licenses/eurooffice/LICENSE"
# Upstream license notice (Ascensio header + AGPL reference), when present.
for upstream_license in LICENSE LICENSE.txt; do
  if [[ -f "$upstream_root/$upstream_license" ]]; then
    install -Dm644 "$upstream_root/$upstream_license" "$pkgroot/usr/share/licenses/eurooffice/LICENSE.upstream"
    break
  fi
done
# Preserve the upstream icon under the DINX desktop-entry name.
icon_src=$(find "$pkgroot/usr/share/icons" -type f \( -name '*.png' -o -name '*.svg' \) 2>/dev/null | head -1 || true)
if [[ -n "$icon_src" ]]; then
  install -Dm644 "$icon_src" "$pkgroot/usr/share/icons/hicolor/256x256/apps/eurooffice.png"
fi

installed_bytes=$(du -sb "$pkgroot" | cut -f1)
{
  printf 'EuroOffice %s DINX lean repack\n' "$version"
  printf 'Upstream: https://github.com/%s/releases/tag/v%s\n' "$upstream_repo" "$version"
  printf 'Upstream deb: %s\n' "$deb_url"
  printf 'Upstream deb sha256: %s\n' "$deb_sha256"
  printf 'License: AGPL-3.0 (see /usr/share/licenses/eurooffice/)\n'
  printf '\nDebloat manifest (label, bytes, path):\n'
  cat "$trim_manifest"
} > "$pkgroot/usr/share/doc/eurooffice/SOURCE"

# --- 7. pacman package ---------------------------------------------------------
pkg_name="eurooffice-${version}-${pkgrel}-x86_64.pkg.tar.zst"
depends=(
  gtk3 nss libxss libxtst alsa-lib libpulse libnotify xdg-utils fontconfig
  libxkbcommon-x11 xcb-util-cursor libglvnd
  ttf-liberation ttf-dejavu ttf-carlito
  gstreamer gst-libav gst-plugins-ugly
)
{
  printf 'pkgname = eurooffice\n'
  printf 'pkgbase = eurooffice\n'
  # pacman 7 / libalpm 16: combined version, no separate pkgrel key.
  printf 'pkgver = %s-%s\n' "$version" "$pkgrel"
  printf 'xdata = pkgtype=pkg\n'
  printf 'pkgdesc = EuroOffice desktop editors (DINX lean repack: documents, spreadsheets, presentations, PDF)\n'
  printf 'url = https://euro-office.github.io/\n'
  printf 'builddate = %s\n' "$(date -u +%s)"
  printf 'packager = DINX Office Pipeline\n'
  printf 'size = %s\n' "$installed_bytes"
  printf 'arch = x86_64\n'
  printf 'license = AGPL-3.0-only\n'
  for dep in "${depends[@]}"; do printf 'depend = %s\n' "$dep"; done
} > "$pkgroot/.PKGINFO"

install -Dm644 "$script_dir/assets/eurooffice.install" "$pkgroot/.INSTALL"

# .MTREE: pacman file database (dirs, files with sha256, symlinks).
{
  printf '#mtree\n'
  while IFS= read -r -d '' entry; do
    rel=${entry#"$pkgroot"}
    rel=./${rel#/}
    if [[ -L "$entry" ]]; then
      printf '%s type=link mode=0777 link=%s\n' "$rel" "$(readlink -- "$entry")"
    elif [[ -d "$entry" ]]; then
      printf '%s type=dir mode=%s\n' "$rel" "$(stat -c '%a' -- "$entry")"
    else
      printf '%s type=file mode=%s size=%s sha256digest=%s\n' \
        "$rel" "$(stat -c '%a' -- "$entry")" "$(stat -c '%s' -- "$entry")" \
        "$(sha256sum -- "$entry" | cut -d' ' -f1)"
    fi
  done < <(find "$pkgroot/opt" "$pkgroot/usr" -mindepth 0 -print0 | LC_ALL=C sort -z)
} > "$pkgroot/.MTREE"

tar --zstd -cf "$outdir/$pkg_name" -C "$pkgroot" .PKGINFO .MTREE .INSTALL opt usr
log "package: $outdir/$pkg_name ($(stat -c '%s' "$outdir/$pkg_name") bytes)"

# --- 8. Live squashfs -----------------------------------------------------------
squash_name="eurooffice-${version}-x86_64.squashfs"
rm -f -- "$outdir/$squash_name"
mksquashfs "$pkgroot" "$outdir/$squash_name" \
  -comp xz -b 1048576 -Xbcj x86 -Xdict-size 1048576 \
  -no-exports -no-xattrs -all-root -no-progress -noappend \
  -e .PKGINFO .MTREE .INSTALL
log "squashfs: $outdir/$squash_name ($(stat -c '%s' "$outdir/$squash_name") bytes)"

# --- 9. Checksums + build metadata ----------------------------------------------
(cd "$outdir" && sha256sum "$pkg_name" "$squash_name" > SHA256SUMS)
jq -n \
  --arg version "$version" \
  --arg pkgrel "$pkgrel" \
  --arg upstream_repo "$upstream_repo" \
  --arg deb_url "$deb_url" \
  --arg deb_sha256 "$deb_sha256" \
  --arg asset_name "$asset_name" \
  --argjson deb_bytes "$deb_bytes" \
  --argjson upstream_installed_bytes "$upstream_installed_bytes" \
  --argjson installed_bytes "$installed_bytes" \
  --argjson removed_bytes "$removed_bytes" \
  --argjson stripped "$stripped" \
  --argjson strip_failures "$strip_failures" \
  --arg keep_dicts "$keep_dicts" \
  --arg keep_locales "$keep_locales" \
  --arg keep_templates "$keep_templates" \
  --arg pkg_name "$pkg_name" \
  --arg squash_name "$squash_name" \
  --arg built_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg pipeline_sha256 "$(sha256sum "$script_dir/build.sh" | cut -d' ' -f1)" \
  '{schema: "dinx-eurooffice-build/v1", version: $version, pkgrel: ($pkgrel|tonumber),
    upstream: {repo: $upstream_repo, tag: ("v" + $version), deb_url: $deb_url,
               deb_asset: $asset_name, deb_sha256: $deb_sha256, deb_bytes: $deb_bytes,
               installed_bytes: $upstream_installed_bytes},
    debloat: {removed_bytes: $removed_bytes, keep_dicts: ($keep_dicts|split(" ")),
              keep_locales: ($keep_locales|split(" ")),
              keep_templates: ($keep_templates|split(" "))},
    strip: {stripped: $stripped, failures: $strip_failures},
    installed_bytes: $installed_bytes,
    artifacts: {package: $pkg_name, squashfs: $squash_name},
    built_at: $built_at, pipeline_sha256: $pipeline_sha256}' \
  > "$outdir/build-metadata.json"

# --- 10. Sanity checks -----------------------------------------------------------
squash_listing=$(unsquashfs -l "$outdir/$squash_name")
grep -Fq 'opt/eurooffice/DesktopEditors' <<<"$squash_listing" \
  || { printf 'build: squashfs missing DesktopEditors\n' >&2; exit 1; }
grep -Fq 'usr/bin/eurooffice' <<<"$squash_listing" \
  || { printf 'build: squashfs missing launcher\n' >&2; exit 1; }
launcher_check=$(unsquashfs -cat "$outdir/$squash_name" usr/bin/eurooffice 2>/dev/null || unsquashfs -no-progress -cat "$outdir/$squash_name" usr/bin/eurooffice)
grep -Fq '/opt/eurooffice' <<<"$launcher_check" \
  || { printf 'build: launcher does not target /opt/eurooffice\n' >&2; exit 1; }
grep -Fq 'LD_PRELOAD' <<<"$launcher_check" \
  || { printf 'build: launcher missing LD_PRELOAD\n' >&2; exit 1; }
pkg_listing=$(tar -tf "$outdir/$pkg_name")
grep -Fqx '.PKGINFO' <<<"$pkg_listing" \
  || { printf 'build: package missing .PKGINFO\n' >&2; exit 1; }
grep -Fqx '.MTREE' <<<"$pkg_listing" \
  || { printf 'build: package missing .MTREE\n' >&2; exit 1; }
if command -v pacman >/dev/null 2>&1; then
  pacman -Qip "$outdir/$pkg_name" >/dev/null \
    || { printf 'build: pacman rejects package metadata\n' >&2; exit 1; }
  pacman -Qlp "$outdir/$pkg_name" >/dev/null \
    || { printf 'build: pacman rejects package file list (.MTREE)\n' >&2; exit 1; }
fi

log "done: upstream_installed=$upstream_installed_bytes lean_installed=$installed_bytes removed=$removed_bytes"
log "artifacts in $outdir"