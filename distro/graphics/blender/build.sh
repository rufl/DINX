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
full_checksum_url=${BLENDER_FULL_CHECKSUM_URL:-https://download.blender.org/release/Blender${version%.*}/blender-${version}.sha256}
full_sha=${BLENDER_FULL_SHA256:-}
user_agent=${BLENDER_DOWNLOAD_USER_AGENT:-DINX-Blender-Build/1}
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { printf 'build: invalid Blender version\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'build: jq is required\n' >&2; exit 1; }
command -v makepkg >/dev/null || { printf 'build: makepkg is required\n' >&2; exit 1; }
mkdir -p "$outdir"
workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
recipe_dir="$workdir/blender"
cp -a "$repo_root/distro/packages/blender/." "$recipe_dir/"
source_asset=$(basename -- "$source_url")
source_archive="$workdir/$source_asset"
curl -fsSL -A "$user_agent" "$source_url" -o "$source_archive"
if [[ -z "$source_sha" ]]; then
  source_sha=$(sha256sum "$source_archive" | awk '{ print $1 }')
fi
source_url="file://$source_archive"
full_asset=$(basename -- "$full_url")
full_archive="$workdir/$full_asset"
curl -fsSL -A "$user_agent" "$full_url" -o "$full_archive"
if [[ -z "$full_sha" ]]; then
  full_sha=$(curl -fsSL -A "$user_agent" "$full_checksum_url" \
    | awk -v name="$full_asset" '$2 == name { print $1; exit }')
fi
downloaded_full_sha=$(sha256sum "$full_archive" | awk '{ print $1 }')
if [[ -n "$full_sha" && "$full_sha" != "$downloaded_full_sha" ]]; then
  printf 'build: full archive checksum mismatch (expected %s, got %s)\n' \
    "$full_sha" "$downloaded_full_sha" >&2
  exit 1
fi
full_sha="$downloaded_full_sha"
[[ "$source_sha" =~ ^[0-9a-f]{64}$ && "$full_sha" =~ ^[0-9a-f]{64}$ ]] || {
  printf 'build: missing verified Blender source checksums\n' >&2; exit 1
}
printf 'BLENDER_VERSION=%s\nBLENDER_SOURCE_URL=%s\nBLENDER_SOURCE_SHA256=%s\n' \
  "$version" "$source_url" "$source_sha" > "$recipe_dir/source.env"
rm -f "$recipe_dir"/*.pkg.tar.zst
source_dest="$workdir/sources"
mkdir -p "$source_dest"
makepkg --cleanbuild --syncdeps --noconfirm --clean --log --dir "$recipe_dir" \
  SRCDEST="$source_dest"
lean_package=$(find "$recipe_dir" -maxdepth 1 -type f -name 'blender-*.pkg.tar.zst' -print -quit)
[[ -n "$lean_package" ]] || { printf 'build: lean Blender package missing\n' >&2; exit 1; }
if [[ "${BLENDER_LEAN_ONLY:-0}" == 1 ]]; then
  lean_source_name=$(basename -- "$lean_package")
  lean_name=${lean_source_name//:/\.}
  cp -- "$lean_package" "$outdir/$lean_name"
  (cd "$outdir" && sha256sum "$lean_name" > SHA256SUMS)
  jq -n --arg version "$version" --arg pkgrel "$pkgrel" --arg source_sha "$source_sha" \
    --arg full_sha "$full_sha" --arg lean "$lean_name" \
    --argjson lean_workflows '["modeling","rigging","texturing","animation"]' \
    --argjson lean_omitted '["xr","usd","materialx","openvdb","opensubdiv","embree","openimagedenoise","oneapi","cycles-osl","grease-pencil","haru"]' \
    '{
      schema:"dinx-blender-build/v1",
      mode:"lean-only-staging",
      version:$version,
      pkgrel:($pkgrel|tonumber),
      upstream:{source_sha256:$source_sha,full_binary_sha256:$full_sha},
      artifacts:{lean_package:$lean},
      packages:{lean:{artifact:$lean,workflows:$lean_workflows,omitted:$lean_omitted}}
    }' > "$outdir/build-metadata.json"
  printf 'blender-build: lean=%s (lean-only staging)\n' "$lean_name"
  exit 0
fi
full_dir="$workdir/blender-full"
full_payload="$workdir/full-payload"
mkdir -p "$full_dir" "$full_payload"
tar -xJf "$full_archive" -C "$full_payload"
full_payload_dir="$full_payload/blender-$version-linux-x64"
[[ -d "$full_payload_dir" ]] || {
  printf 'build: full Blender payload directory missing\n' >&2
  exit 1
}
cat > "$full_dir/PKGBUILD" <<EOF
pkgname=blender-full
pkgver=$version
pkgrel=$pkgrel
pkgdesc='Full upstream Blender release with all features; replaces the DINX lean package'
arch=(x86_64)
url=https://www.blender.org/
license=(GPL-3.0-or-later)
conflicts=(blender)
provides=("blender=\$pkgver")
replaces=(blender)
depends=(bash glibc libglvnd wayland xdg-utils)
source=()
sha256sums=()
package() {
  local payload="$full_payload_dir"
  install -dm755 "\$pkgdir/opt/blender" "\$pkgdir/usr/bin" "\$pkgdir/usr/share/applications" "\$pkgdir/usr/share/licenses/blender-full"
  cp -a "\$payload/." "\$pkgdir/opt/blender/"
  ln -s /opt/blender/blender "\$pkgdir/usr/bin/blender"
  ln -s /opt/blender/blender "\$pkgdir/usr/bin/blender-full"
  cp -a "\$payload/license/." "\$pkgdir/usr/share/licenses/blender-full/"
  cat > "\$pkgdir/usr/share/applications/blender.desktop" <<DESKTOP
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
makepkg --cleanbuild --syncdeps --noconfirm --clean --log --dir "$full_dir" \
  SRCDEST="$source_dest"
full_package=$(find "$full_dir" -maxdepth 1 -type f -name 'blender-full-*.pkg.tar.zst' -print -quit)
[[ -n "$full_package" ]] || { printf 'build: full Blender package missing\n' >&2; exit 1; }
lean_source_name=$(basename -- "$lean_package")
full_source_name=$(basename -- "$full_package")
lean_name=${lean_source_name//:/\.}
full_name=${full_source_name//:/\.}
cp -- "$lean_package" "$outdir/$lean_name"
cp -- "$full_package" "$outdir/$full_name"
(cd "$outdir" && sha256sum "$lean_name" "$full_name" > SHA256SUMS)
jq -n --arg version "$version" --arg pkgrel "$pkgrel" --arg source_sha "$source_sha" \
  --arg full_sha "$full_sha" --arg lean "$lean_name" --arg full "$full_name" \
  --argjson lean_workflows '["modeling","rigging","texturing","animation"]' \
  --argjson lean_omitted '["xr","usd","materialx","openvdb","opensubdiv","embree","openimagedenoise","oneapi","cycles-osl","grease-pencil","haru"]' \
  '{
    schema:"dinx-blender-build/v1",
    version:$version,
    pkgrel:($pkgrel|tonumber),
    upstream:{source_sha256:$source_sha,full_binary_sha256:$full_sha},
    artifacts:{lean_package:$lean,full_package:$full},
    packages:{
      lean:{artifact:$lean,workflows:$lean_workflows,omitted:$lean_omitted},
      full:{artifact:$full,scope:"all-upstream-features",replaces:"blender"}
    }
  }' > "$outdir/build-metadata.json"
printf 'blender-build: lean=%s full=%s\n' "$lean_name" "$full_name"
