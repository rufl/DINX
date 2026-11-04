#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/lib/dinx-package-artifact-cache.sh"
command -v gpg >/dev/null || { printf 'smoke_package_artifact_cache: gpg is required\n' >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cache_root="$tmp/cache"
package_dir="$tmp/package"
package_repo="$tmp/repo"
source_root="$tmp/source-root"
signing_home="$tmp/gnupg"
mkdir -p "$package_dir" "$package_repo" "$signing_home" "$package_dir/src" "$source_root/share/licenses"
chmod 700 "$signing_home"
printf 'pkgname=cache-smoke\npkgver=1\n' > "$package_dir/PKGBUILD"
printf 'source payload v1\n' > "$package_dir/payload"
printf 'const source = true;\n' > "$package_dir/src/main.zig"
printf 'share/licenses/DINX\n' > "$package_dir/cache-inputs"
printf 'external license v1\n' > "$source_root/share/licenses/DINX"

printf 'base makepkg config\n' > "$tmp/makepkg.conf"
printf 'builder source\n' > "$tmp/builder"
printf 'installed package set\n' > "$tmp/installed"
makepkg_conf_sha256=$(sha256sum "$tmp/makepkg.conf" | cut -d ' ' -f 1)
builder_sha256=$(sha256sum "$tmp/builder" | cut -d ' ' -f 1)
installed_packages_sha256=$(sha256sum "$tmp/installed" | cut -d ' ' -f 1)
cache_key() {
  dinx_package_cache_key demo "$package_dir" "$makepkg_conf_sha256" \
    "$builder_sha256" "$installed_packages_sha256" "$source_root" --nodeps -- 'FEATURE=one'
}
key=$(cache_key)
external_key=$key
printf 'external license v2\n' > "$source_root/share/licenses/DINX"
[[ "$(cache_key)" != "$external_key" ]] || {
  printf 'smoke_package_artifact_cache: declared external source file did not invalidate cache key\n' >&2
  exit 1
}
printf 'external license v1\n' > "$source_root/share/licenses/DINX"
outside_input="$tmp/outside-license"
printf 'external file outside source root\n' > "$outside_input"
ln -s "$outside_input" "$source_root/share/licenses/outside"
printf 'share/licenses/outside\n' > "$package_dir/cache-inputs"
if cache_key >/dev/null 2>&1; then
  printf 'smoke_package_artifact_cache: external source symlink escaped the source root\n' >&2
  exit 1
fi
printf '../outside-license\n' > "$package_dir/cache-inputs"
if cache_key >/dev/null 2>&1; then
  printf 'smoke_package_artifact_cache: external source path traversal was accepted\n' >&2
  exit 1
fi
rm "$source_root/share/licenses/outside"
printf 'share/licenses/DINX\n' > "$package_dir/cache-inputs"
export DINX_ARTIX_IMAGE=example.invalid/artix@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
image_key=$(cache_key)
export DINX_ARTIX_IMAGE=example.invalid/artix@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
image_key_changed=$(cache_key)
[[ "$image_key_changed" != "$image_key" ]] || {
  printf 'smoke_package_artifact_cache: Artix image did not invalidate cache key\n' >&2
  exit 1
}
unset DINX_ARTIX_IMAGE
[[ "$(cache_key)" == "$key" ]] || {
  printf 'smoke_package_artifact_cache: restoring external inputs did not restore the key\n' >&2
  exit 1
}
direct_source_key=$(dinx_package_cache_key dinitui "$package_dir" "$makepkg_conf_sha256" \
  "$builder_sha256" "$installed_packages_sha256" "$source_root" --nodeps -- 'FEATURE=one')
mkdir -p "$package_dir/.zig-cache/o" "$package_dir/zig-cache" \
  "$package_dir/src/.zig-cache/o" "$package_dir/src/zig-out/bin" \
  "$package_dir/src/stage/bin" "$package_dir/pkg/demo"
printf 'generated zig cache\n' > "$package_dir/.zig-cache/o/generated"
printf 'generated nested cache\n' > "$package_dir/src/.zig-cache/o/generated"
printf 'generated binary\n' > "$package_dir/src/zig-out/bin/demo"
printf 'generated package staging\n' > "$package_dir/src/stage/bin/demo"
printf 'generated package contents\n' > "$package_dir/pkg/demo/archive"
[[ "$(cache_key)" == "$key" ]] || {
  printf 'smoke_package_artifact_cache: generated output changed a non-source package key\n' >&2
  exit 1
}
[[ "$(dinx_package_cache_key dinitui "$package_dir" "$makepkg_conf_sha256" \
  "$builder_sha256" "$installed_packages_sha256" "$source_root" --nodeps -- 'FEATURE=one')" == "$direct_source_key" ]] || {
  printf 'smoke_package_artifact_cache: generated output changed a checked-in source package key\n' >&2
  exit 1
}
archive_one="$tmp/demo-1.0-1-any.pkg.tar.zst"
archive_two="$tmp/demo-debug-1.0-1-any.pkg.tar.zst"
printf 'package archive one\n' > "$archive_one"
printf 'package archive two\n' > "$archive_two"

if dinx_package_cache_restore "$cache_root" demo "$key" "$package_repo" "$signing_home"; then
  printf 'smoke_package_artifact_cache: empty cache unexpectedly hit\n' >&2
  exit 1
else
  status=$?
  [[ $status -eq 1 ]] || { printf 'smoke_package_artifact_cache: empty cache returned %s\n' "$status" >&2; exit 1; }
fi

dinx_package_cache_store "$cache_root" demo "$key" "$archive_one" "$archive_two"
cache_entry="$cache_root/demo/$key"
[[ -f "$cache_entry/metadata" && -f "$cache_entry/SHA256SUMS" ]]
[[ ! -e "$cache_entry/$(basename -- "$archive_one").sig" ]]

gpg --batch --homedir "$signing_home" --pinentry-mode loopback --passphrase '' \
  --quick-generate-key 'DINX package cache smoke <cache@dinx.invalid>' ed25519 sign 0 >/dev/null 2>&1

dinx_package_cache_restore "$cache_root" demo "$key" "$package_repo" "$signing_home"
pacman_cache="$tmp/pacman-cache"
stale_signing_home="$tmp/stale-gnupg"
mkdir -p "$pacman_cache" "$stale_signing_home"
chmod 700 "$stale_signing_home"
gpg --batch --homedir "$stale_signing_home" --pinentry-mode loopback --passphrase '' \
  --quick-generate-key 'DINX stale package cache smoke <stale-cache@dinx.invalid>' ed25519 sign 0 \
  >/dev/null 2>&1
cached_name=$(basename -- "$archive_one")
cached_archive="$pacman_cache/$cached_name"
cp -- "$archive_one" "$cached_archive"
gpg --batch --yes --homedir "$stale_signing_home" --detach-sign \
  --output "$cached_archive.sig" "$cached_archive"
if gpg --batch --homedir "$signing_home" --verify \
  "$cached_archive.sig" "$cached_archive" >/dev/null 2>&1; then
  printf 'smoke_package_artifact_cache: stale signature unexpectedly validates under the current repository key\n' >&2
  exit 1
fi
unrelated_archive="$pacman_cache/artix-unrelated-1-any.pkg.tar.zst"
printf 'unrelated upstream package cache entry\n' > "$unrelated_archive"
dinx_invalidate_pacman_package_cache "$package_repo" "$pacman_cache"
[[ ! -e "$cached_archive" && ! -e "$cached_archive.sig" ]] || {
  printf 'smoke_package_artifact_cache: DINX archive/signature cache entries were not invalidated\n' >&2
  exit 1
}
[[ -f "$unrelated_archive" ]] || {
  printf 'smoke_package_artifact_cache: unrelated upstream cache entry was removed\n' >&2
  exit 1
}
printf 'smoke_package_artifact_cache: stale ephemeral-signature cache invalidation passed\n'
for archive in "$archive_one" "$archive_two"; do
  name=$(basename -- "$archive")
  cmp -- "$archive" "$package_repo/$name"
  gpg --batch --homedir "$signing_home" --verify "$package_repo/$name.sig" "$package_repo/$name" >/dev/null 2>&1
  rm -f -- "$package_repo/$name" "$package_repo/$name.sig"
done

printf 'corrupted cache content\n' > "$cache_entry/$(basename -- "$archive_one")"
if dinx_package_cache_restore "$cache_root" demo "$key" "$package_repo" "$signing_home"; then
  printf 'smoke_package_artifact_cache: corrupted cache unexpectedly hit\n' >&2
  exit 1
else
  status=$?
  [[ $status -eq 1 ]] || { printf 'smoke_package_artifact_cache: corrupt cache returned %s\n' "$status" >&2; exit 1; }
fi
[[ ! -e "$cache_entry" ]]
if dinx_package_cache_restore "$cache_root" demo "$key" "$package_repo" "$signing_home"; then
  printf 'smoke_package_artifact_cache: evicted cache unexpectedly hit\n' >&2
  exit 1
else
  status=$?
  [[ $status -eq 1 ]]
fi

dinx_package_cache_store "$cache_root" demo "$key" "$archive_one" "$archive_two"
dinx_package_cache_restore "$cache_root" demo "$key" "$package_repo" "$signing_home"
gpg --batch --homedir "$signing_home" --verify \
  "$package_repo/$(basename -- "$archive_one").sig" \
  "$package_repo/$(basename -- "$archive_one")" >/dev/null 2>&1

old_source=$(cat "$package_dir/src/main.zig")
printf 'const changed_source = true;\n' > "$package_dir/src/main.zig"
changed_direct_source_key=$(dinx_package_cache_key dinitui "$package_dir" "$makepkg_conf_sha256" \
  "$builder_sha256" "$installed_packages_sha256" "$source_root" --nodeps -- 'FEATURE=one')
[[ "$changed_direct_source_key" != "$direct_source_key" ]]
printf '%s\n' "$old_source" > "$package_dir/src/main.zig"

changed_environment_key=$(dinx_package_cache_key demo "$package_dir" "$makepkg_conf_sha256" \
  "$builder_sha256" "$installed_packages_sha256" "$source_root" --nodeps -- 'FEATURE=two')
[[ "$changed_environment_key" != "$key" ]]
changed_packages_sha256=$(printf 'different installed package set\n' | sha256sum | cut -d ' ' -f 1)
changed_packages_key=$(dinx_package_cache_key demo "$package_dir" "$makepkg_conf_sha256" \
  "$builder_sha256" "$changed_packages_sha256" "$source_root" --nodeps -- 'FEATURE=one')
[[ "$changed_packages_key" != "$key" ]]

partial_key=$(printf 'partial artifact key\n' | sha256sum | cut -d ' ' -f 1)
if dinx_package_cache_store "$cache_root" demo "$partial_key" \
  "$archive_one" "$tmp/missing-archive.pkg.tar.zst"; then
  printf 'smoke_package_artifact_cache: incomplete package set was stored\n' >&2
  exit 1
fi
[[ ! -e "$cache_root/demo/$partial_key" ]]
if find "$cache_root/demo" -maxdepth 1 -type d -name ".$partial_key.tmp.*" -print -quit | grep -q .; then
  printf 'smoke_package_artifact_cache: failed store left a temporary cache entry\n' >&2
  exit 1
fi

printf 'smoke_package_artifact_cache: miss, verified hit, corruption eviction, key invalidation and incomplete-store checks passed\n'
