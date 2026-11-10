#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: Apache-2.0
#
# Build a locally patched proof ISO from a canonical P0 run artifact, with
# caching. Downloaded artifacts, checksum validation and the extracted ISO
# tree are reused per run-id until --force is given; only the final ISO
# assembly always re-runs.
#
# Usage:
#   scripts/proof-iso.sh [--force] [--cache-dir DIR] <run-id> <patched-livefs.img> <output.iso>
#
# Cache layout (default: dist/proof-cache):
#   <run-id>.iso                    canonical artifact ISO
#   <run-id>.build-metadata.txt     its build-metadata.txt
#   <run-id>.validated              stamp holding the validated sha512
#   <run-id>.tree/                  extracted ISO tree (livefs.img is the
#                                   original squashfs; replaced per build)
#
# The patched livefs image is dropped into the extracted tree as
# LiveOS/livefs.img together with its md5, then a fresh ISO is written with
# mkisofs replaying the original El Torito/grub2-mbr boot configuration.
set -euo pipefail

force=false
cache_dir=
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force=true; shift ;;
    --cache-dir) cache_dir=${2:?--cache-dir needs a value}; shift 2 ;;
    --help|-h)
      sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) positional+=("$1"); shift ;;
  esac
done

[[ ${#positional[@]} -eq 3 ]] || { printf 'usage: %s [--force] [--cache-dir DIR] <run-id> <patched-livefs.img> <output.iso>\n' "$0" >&2; exit 2; }
run_id=${positional[0]}
patched_livefs=${positional[1]}
output_iso=${positional[2]}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(git -C "$script_dir/.." rev-parse --show-toplevel)
cache_dir=${cache_dir:-"$repo_root/dist/proof-cache"}
mkdir -p "$cache_dir"

for command in gh xorriso sha512sum md5sum unzip; do
  command -v "$command" >/dev/null 2>&1 || { printf 'missing required command: %s\n' "$command" >&2; exit 1; }
done
[[ -r $patched_livefs ]] || { printf 'patched livefs image not readable: %s\n' "$patched_livefs" >&2; exit 1; }

repo=$(git -C "$repo_root" remote get-url origin | sed -E 's#.*github\.com[:/]##; s#\.git$##')
cached_iso="$cache_dir/$run_id.iso"
cached_metadata="$cache_dir/$run_id.build-metadata.txt"
validated_stamp="$cache_dir/$run_id.validated"
tree_dir="$cache_dir/$run_id.tree"

download_artifact() {
  local artifacts artifact_id tmp found metadata
  tmp=$(mktemp -d)
  artifacts=$(gh api "repos/$repo/actions/runs/$run_id/artifacts" --jq '[.artifacts | sort_by(.size_in_bytes) | reverse | .[0] | {id: .id, name: .name}] | .[0]')
  artifact_id=$(jq -r .id <<<"$artifacts")
  [[ $artifact_id != null && -n $artifact_id ]] || { printf 'no artifact found for run %s\n' "$run_id" >&2; exit 1; }
  printf 'downloading artifact %s (%s) for run %s\n' "$artifact_id" "$(jq -r .name <<<"$artifacts")" "$run_id"
  gh api "repos/$repo/actions/artifacts/$artifact_id/zip" > "$tmp/artifact.zip"
  unzip -o -q "$tmp/artifact.zip" -d "$tmp"
  found=$(find "$tmp" -type f -name '*.iso' -print -quit)
  [[ -n $found ]] || { printf 'artifact for run %s contains no ISO\n' "$run_id" >&2; exit 1; }
  mv "$found" "$cached_iso"
  metadata=$(dirname "$found")/build-metadata.txt
  [[ -r $metadata ]] && cp "$metadata" "$cached_metadata"
  rm -rf "$tmp" "$tree_dir"
}

if [[ ! -r $cached_iso || $force == true ]]; then
  download_artifact
elif [[ -r $validated_stamp ]]; then
  printf 'reusing cached validated artifact for run %s; pass --force to re-download\n' "$run_id"
else
  printf 'cached artifact for run %s was never validated; validating\n' "$run_id"
fi

[[ -r $cached_metadata ]] || { printf 'build-metadata.txt missing for run %s; pass --force to re-download\n' "$run_id" >&2; exit 1; }
expected_sha512=$(grep -E '^iso_sha512=' "$cached_metadata" | cut -d= -f2)
[[ -n $expected_sha512 ]] || { printf 'iso_sha512 missing in %s\n' "$cached_metadata" >&2; exit 1; }
actual_sha512=$(sha512sum "$cached_iso" | cut -d' ' -f1)
[[ $actual_sha512 == "$expected_sha512" ]] || {
  printf 'cached ISO sha512 mismatch; expected %s, got %s\n' "$expected_sha512" "$actual_sha512" >&2
  printf 're-run with --force to re-download\n' >&2
  exit 1
}
if [[ ! -r $validated_stamp || $(cat "$validated_stamp") != "$expected_sha512" ]]; then
  printf '%s' "$expected_sha512" > "$validated_stamp"
fi
printf 'artifact validated: run=%s bytes=%s sha512=%s (stamp %s)\n' \
  "$run_id" "$(grep -E '^iso_bytes=' "$cached_metadata" | cut -d= -f2)" "$expected_sha512" "$(date -u +%F)"

if [[ ! -d $tree_dir/LiveOS ]]; then
  printf 'extracting ISO tree for run %s (cached afterwards)\n' "$run_id"
  rm -rf "$tree_dir"
  mkdir -p "$tree_dir"
  xorriso -osirrox on -indev "$cached_iso" -extract / "$tree_dir" >/dev/null 2>&1
  chmod -R u+w "$tree_dir"
fi

cp "$patched_livefs" "$tree_dir/LiveOS/livefs.img"
md5sum "$patched_livefs" | cut -d' ' -f1 | tr -d '\n' > "$tree_dir/LiveOS/livefs.img.md5"
printf ' *%s\n' "$(basename "$patched_livefs")" >> "$tree_dir/LiveOS/livefs.img.md5"

mapfile -t boot_opts < <(xorriso -indev "$cached_iso" -report_el_torito as_mkisofs 2>/dev/null)
# Replay the recorded boot configuration; interval references point at the
# cached ISO file and stay valid across rebuilds.
rm -f "$output_iso"
xorriso -as mkisofs -r "${boot_opts[@]}" -o "$output_iso" "$tree_dir" >/dev/null 2>&1 \
  || { printf 'mkisofs replay failed for run %s\n' "$run_id" >&2; exit 1; }

printf 'proof ISO: %s (%s bytes)\n' "$output_iso" "$(stat -c %s "$output_iso")"
