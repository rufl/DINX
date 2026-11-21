#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build the lean DINX Blender package and a replaceable full-feature package.
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
outdir=${BLENDER_OUTDIR:-$repo_root/dist/graphics/blender}
version=${BLENDER_VERSION:?BLENDER_VERSION is required}
pkgrel=${BLENDER_PKREL:-1}
source_url=${BLENDER_SOURCE_URL:-https://download.blender.org/source/blender-${version}.tar.xz}
source_sha=${BLENDER_SOURCE_SHA256:-}
full_url=${BLENDER_FULL_URL:-https://download.blender.org/release/Blender${version%.*}/blender-${version}-linux-x64.tar.xz}
full_sha=${BLENDER_FULL_SHA256:-}
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { printf 'build: invalid Blender version\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'build: jq is required\n' >&2; exit 1; }
command -v makepkg >/dev/null || { printf 'build: makepkg is required\n' >&2; exit 1; }
mkdir -p "$outdir"
workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
recipe_dir="$workdir/blender"
cp -a "$repo_root/distro/packages/blender/." "$recipe_dir/"
if [[ -z "$source_sha" ]]; then
  source_sha=$(curl -fsSL "${source_url}.sha256" | awk 'NR == 1 { print $1; exit }')
fi
if [[ -z "$full_sha" ]]; then
  full_sha=$(curl -fsSL "${full_url}.sha256" | awk 'NR == 1 { print $1; exit }')
fi
[[ "$source_sha" =~ ^[0-9a-f]{64}$ && "$full_sha" =~ ^[0-9a-f]{64}$ ]] || {
  printf 'build: missing verified Blender source checksums\n' >&2; exit 1
}
printf 'BLENDER_VERSION=%s\nBLENDER_SOURCE_URL=%s\nBLENDER_SOURCE_SHA256=%s\n' \
  "$version" "$source_url" "$source_sha" > "$recipe_dir/source.env"
rm -f "$recipe_dir"/*.pkg.tar.zst
makepkg --cleanbuild --syncdeps --noconfirm --clean --log --dir "$recipe_dir"
lean_package=$(find "$recipe_dir" -maxdepth 1 -type f -name 'blender-*.pkg.tar.zst' -print -quit)
[[ -n "$lean_package" ]] || { printf 'build: lean Blender package missing\n' >&2; exit 1; }
full_dir="$workdir/blender-full"
mkdir -p "$full_dir"
cat > "$full_dir/PKGBUILD" <<EOF
pkgname=blender-full
pkgver=$version
pkgrel=$pkgrel
pkgdesc='Full-featured Blender release replacing the DINX lean Blender package'
arch=(x86_64)
url=https://www.blender.org/
license=(GPL-3.0-or-later)
conflicts=(blender)
provides=("blender=\$pkgver")
depends=(bash glibc libglvnd wayland xdg-utils)
source=("blender-full-\$pkgver.tar.xz::$full_url")
sha256sums=(\"$full_sha\")
package() {
  local payload=\"\$srcdir/blender-\$pkgver-linux-x64\"
  install -dm755 \"\$pkgdir/opt/blender\" \"\$pkgdir/usr/bin\" \"\$pkgdir/usr/share/applications\" \"\$pkgdir/usr/share/licenses/blender-full\"
  cp -a \"\$payload/.\" \"\$pkgdir/opt/blender/\"
  ln -s /opt/blender/blender \"\$pkgdir/usr/bin/blender\"
  ln -s /opt/blender/blender \"\$pkgdir/usr/bin/blender-full\"
  install -Dm644 \"\$payload/license\" \"\$pkgdir/usr/share/licenses/blender-full/LICENSE\"
  cat > \"\$pkgdir/usr/share/applications/blender.desktop\" <<DESKTOP
[Desktop Entry]
Name=Blender (Full)
Comment=Full-featured 3D creation suite
Exec=blender %f
Icon=blender
Terminal=false
Type=Application
Categories=Graphics;3DGraphics;
MimeType=application/x-blender;
DESKTOP
}
EOF
makepkg --cleanbuild --syncdeps --noconfirm --clean --log --dir "$full_dir"
full_package=$(find "$full_dir" -maxdepth 1 -type f -name 'blender-full-*.pkg.tar.zst' -print -quit)
[[ -n "$full_package" ]] || { printf 'build: full Blender package missing\n' >&2; exit 1; }
cp -- "$lean_package" "$full_package" "$outdir/"
lean_name=$(basename -- "$lean_package"); full_name=$(basename -- "$full_package")
(cd "$outdir" && sha256sum "$lean_name" "$full_name" > SHA256SUMS)
jq -n --arg version "$version" --arg pkgrel "$pkgrel" --arg source_sha "$source_sha" \
  --arg full_sha "$full_sha" --arg lean "$lean_name" --arg full "$full_name" \
  '{schema:"dinx-blender-build/v1",version:$version,pkgrel:($pkgrel|tonumber),
    upstream:{source_sha256:$source_sha,full_binary_sha256:$full_sha},
    artifacts:{lean_package:$lean,full_package:$full}}' > "$outdir/build-metadata.json"
printf 'blender-build: lean=%s full=%s\n' "$lean_name" "$full_name"
