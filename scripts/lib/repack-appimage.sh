#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 DINX Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Repack an upstream AppImage as a pre-extracted /opt tree so launches never
# extract into tmpfs. Usage:
#   repack-appimage.sh <AppImage> <dest-dir> [--strip] [--trim-locales]
#
# --strip        strip --strip-unneeded every ELF file (best effort)
# --trim-locales keep only en*/pt* system locales, Qt translations and
#                Chromium/Electron locale paks
set -euo pipefail

if [ "$#" -lt 2 ]; then
  printf 'repack-appimage: usage: repack-appimage.sh <AppImage> <dest-dir> [--strip] [--trim-locales]\n' >&2
  exit 2
fi
appimage=$(realpath -- "$1")
dest=$2
shift 2
strip=0
trim=0
for arg in "$@"; do
  case "$arg" in
    --strip) strip=1 ;;
    --trim-locales) trim=1 ;;
    *) printf 'repack-appimage: unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
chmod +x "$appimage"
(cd "$work" && "$appimage" --appimage-extract >/dev/null)
tree="$work/squashfs-root"
[ -d "$tree" ] || { printf 'repack-appimage: extraction produced no squashfs-root\n' >&2; exit 1; }

if [ "$strip" = 1 ]; then
  while IFS= read -r -d '' f; do
    if [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" = 7f454c46 ]; then
      strip --strip-unneeded "$f" 2>/dev/null || true
    fi
  done < <(find "$tree" -type f -print0)
fi

if [ "$trim" = 1 ]; then
  for locdir in "$tree/usr/share/locale" "$tree/usr/lib/locale"; do
    [ -d "$locdir" ] || continue
    find "$locdir" -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'pt*' -exec rm -rf {} +
  done
  while IFS= read -r -d '' qm; do
    base=${qm##*/}
    case "$base" in
      en*|pt*) ;;
      *) rm -f "$qm" ;;
    esac
  done < <(find "$tree" -type f -name '*.qm' -print0)
  for pakdir in "$tree/locales" "$tree/usr/bin/locales"; do
    [ -d "$pakdir" ] || continue
    find "$pakdir" -maxdepth 1 -type f -name '*.pak' \
      ! -name 'en-US.pak' ! -name 'en-GB.pak' ! -name 'pt-BR.pak' ! -name 'pt-PT.pak' \
      -delete
  done
fi

mkdir -p "$dest"
cp -a "$tree/." "$dest/"
