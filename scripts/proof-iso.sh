#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: Apache-2.0
#
# Build a locally patched proof ISO from a canonical P0 run artifact, with
# same-day caching. Downloaded artifacts, checksum validation and extracted
# payloads are reused until --force is given; only the final ISO assembly
# always re-runs.
#
# Usage:
#   scripts/proof-iso.sh [--force] [--cache-dir DIR] <run-id> <patched-livefs.img> <output.iso>
#
# Cache layout (default: dist/proof-cache):
#   <run-id>.iso                    canonical artifact ISO
#   <run-id>.build-metadata.txt     its build-metadata.txt
#   <run-id>.validated              stamp written only after sha512 match
#
# The output ISO drops /LiveOS/rootfs.img* (install payload, unused by the
# live session) so the repacked image fits the original media size.
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

for command in gh xorriso sha512sum unzip; do
  command -v "$command" >/dev/null 2>&1 || { printf 'missing required command: %s\n' "$command" >&2; exit 1; }
done
[[ -r $patched_livefs ]] || { printf 'patched livefs image not readable: %s\n' "$patched_livefs" >&2; exit 1; }

repo=$(git -C "$repo_root" remote get-url origin | sed -E 's#.*github\.com[:/]##; s#\.git$##')
cached_iso="$cache_dir/$run_id.iso"
cached_metadata="$cache_dir/$run_id.build-metadata.txt"
validated_stamp="$cache_dir/$run_id.validated"

artifact_iso_rel='iso/dinx/artix-dinx-dinit-20261110-x86_64.iso'
download_artifact() {
  local artifacts artifact_id tmp
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
  rm -rf "$tmp"
}

if [[ ! -r $cached_iso || $force == true ]]; then
  download_artifact
elif [[ -r $validated_stamp ]]; then
  printf 'reusing cached validated artifact for run %s (stamp %s); pass --force to re-download\n' "$run_id" "$(cat "$validated_stamp")"
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
printf 'artifact validated: run=%s bytes=%s sha512=%s (stamp %s)\n' "$run_id" "$(grep -E '^iso_bytes=' "$cached_metadata" | cut -d= -f2)" "$expected_sha512" "$(date -u +%F)"

patched_md5=$(mktemp)
md5sum "$patched_livefs" > "$patched_md5"

rm -f "$output_iso"
xorriso \
  -indev "$cached_iso" \
  -outdev "$output_iso" \
  -rm /LiveOS/rootfs.img /LiveOS/rootfs.img.md5 \
  -map "$patched_livefs" /LiveOS/livefs.img \
  -map "$patched_md5" /LiveOS/livefs.img.md5 \
  -boot_image any replay \
  -commit -end
rm -f "$patched_md5"

printf 'proof ISO: %s (%s bytes)\n' "$output_iso" "$(stat -c %s "$output_iso")"
