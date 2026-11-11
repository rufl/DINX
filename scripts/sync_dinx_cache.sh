#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Synchronize DINX pre-compiled packages and upstream pacman package cache.
# Default behavior is DELTA update: only missing or changed packages are fetched.
# Pass --force to re-fetch/update all cached packages.

set -euo pipefail

fail() {
  printf 'sync_dinx_cache: %s\n' "$*" >&2
  exit 1
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cache_dir="${DINX_BUILD_CACHE_DIR:-$repo_root/dist/.cache/dinx}"
force=false
sync_upstream=true
sync_dinx=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      shift
      ;;
    --cache-dir)
      cache_dir=${2:?--cache-dir requires a path}
      shift 2
      ;;
    --upstream-only)
      sync_upstream=true
      sync_dinx=false
      shift
      ;;
    --dinx-only)
      sync_upstream=false
      sync_dinx=true
      shift
      ;;
    --help|-h)
      printf 'Usage: %s [--force] [--cache-dir DIR] [--upstream-only|--dinx-only]\n' "$0"
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

pacman_pkg_dir="$cache_dir/pacman/pkg"
artifact_cache_dir="$cache_dir/package-artifacts"
mkdir -p "$pacman_pkg_dir" "$artifact_cache_dir"

# Clean up broken partial downloads or zero-byte files in pacman cache
find "$pacman_pkg_dir" -type f \( -name '*.part' -o -size 0 \) -delete 2>/dev/null || true

if [[ "$sync_upstream" == true ]]; then
  if [[ "$force" == true ]]; then
    printf 'sync_dinx_cache: --force specified; purging upstream pacman cache\n'
    rm -rf "${pacman_pkg_dir:?}"/*
  else
    cached_count=$(find "$pacman_pkg_dir" -maxdepth 1 -type f -name '*.pkg.tar.zst' 2>/dev/null | wc -l || echo 0)
    printf 'sync_dinx_cache: upstream pacman cache has %s packages (delta mode active)\n' "$cached_count"
  fi
fi

if [[ "$sync_dinx" == true ]]; then
  release_tag="dinx-packages-latest"
  release_url="https://github.com/rufl/DINX/releases/download/$release_tag"
  tmp_sums=$(mktemp)
  trap 'rm -f -- "$tmp_sums"' EXIT

  printf 'sync_dinx_cache: checking pre-compiled DINX package release (%s)...\n' "$release_tag"
  if curl --fail --silent --show-error --location --retry 3 --output "$tmp_sums" "$release_url/SHA256SUMS"; then
    downloaded=0
    skipped=0

    while read -r sha256 archive; do
      [[ -n "$sha256" && -n "$archive" ]] || continue
      [[ "$archive" =~ \.pkg\.tar\.zst$ || "$archive" =~ \.pkg\.tar\.zst\.sig$ ]] || continue

      target_file="$pacman_pkg_dir/$archive"
      needs_download=false

      if [[ "$force" == true ]]; then
        needs_download=true
      elif [[ -f "$target_file" && ! -L "$target_file" ]]; then
        actual_sha256=$(sha256sum "$target_file" | cut -d' ' -f1)
        if [[ "$actual_sha256" != "$sha256" ]]; then
          needs_download=true
        fi
      else
        needs_download=true
      fi

      if [[ "$needs_download" == true ]]; then
        printf 'sync_dinx_cache: delta downloading %s\n' "$archive"
        if curl --fail --silent --show-error --location --retry 3 --output "$target_file" "$release_url/$archive"; then
          actual_sha256=$(sha256sum "$target_file" | cut -d' ' -f1)
          if [[ "$actual_sha256" != "$sha256" ]]; then
            rm -f "$target_file"
            fail "checksum mismatch for $archive: expected $sha256, got $actual_sha256"
          fi
          downloaded=$((downloaded + 1))
        else
          printf 'sync_dinx_cache: warning: failed to download %s; will build from source if required\n' "$archive" >&2
          rm -f "$target_file"
        fi
      else
        skipped=$((skipped + 1))
      fi
    done < "$tmp_sums"

    printf 'sync_dinx_cache: DINX pre-compiled packages sync complete (downloaded: %s, delta cached: %s)\n' \
      "$downloaded" "$skipped"
  else
    printf 'sync_dinx_cache: warning: could not retrieve release SHA256SUMS; skipping pre-compiled sync\n' >&2
  fi
fi
