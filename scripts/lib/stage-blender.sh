#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
pin_file=${BLENDER_PIN_FILE:-$repo_root/distro/graphics/blender/blender.pin}
stage_dir=${BLENDER_STAGE_DIR:-$repo_root/dist/graphics/blender}
[[ -f "$pin_file" ]] || exit 0
tag=$(awk -F= '$1 == "tag" { print $2; exit }' "$pin_file")
package=$(awk -F= '$1 == "package" { print $2; exit }' "$pin_file" | tr -d ' ')
full_package=$(awk -F= '$1 == "full_package" { print $2; exit }' "$pin_file" | tr -d ' ')
mode=$(awk -F= '$1 == "mode" { print $2; exit }' "$pin_file" | tr -d ' ')
if [[ "$mode" == lean-only-staging ]]; then
  [[ -n "$tag" && -n "$package" && "$full_package" == "$package" ]] || {
    printf 'stage-blender: invalid lean-only staging pin: %s\n' "$pin_file" >&2
    exit 1
  }
else
  [[ -n "$tag" && -n "$package" && -n "$full_package" ]] || {
    printf 'stage-blender: invalid pin: %s\n' "$pin_file" >&2
    exit 1
  }
fi
repo=${GITHUB_REPOSITORY:-rufl/DINX}
mkdir -p "$stage_dir"
assets=("$package" SHA256SUMS build-metadata.json)
[[ "$mode" == lean-only-staging ]] || assets+=("$full_package")
for asset in "${assets[@]}"; do
  if [[ ! -s "$stage_dir/$asset" ]]; then
    if ! curl -fsSL "https://github.com/$repo/releases/download/$tag/$asset" -o "$stage_dir/$asset"; then
      printf 'stage-blender: release %s is not available; using source bootstrap\n' "$tag" >&2
      rm -f -- "$stage_dir/$asset"
      exit 0
    fi
  fi
done
if [[ "$mode" == lean-only-staging ]]; then
  command -v jq >/dev/null 2>&1 || {
    printf 'stage-blender: jq is required for lean-only staging validation\n' >&2
    exit 1
  }
  metadata_mode=$(jq -r '.mode // empty' "$stage_dir/build-metadata.json")
  metadata_asset=$(jq -r '.artifacts.lean_package // empty' "$stage_dir/build-metadata.json")
  normalized_asset=${metadata_asset/:/.}
  [[ "$metadata_mode" == lean-only-staging && "$package" == "$normalized_asset" ]] || {
    printf 'stage-blender: staging metadata does not match %s\n' "$pin_file" >&2
    exit 1
  }
  expected_sha=$(awk -v name="$metadata_asset" '$2 == name { print $1; exit }' "$stage_dir/SHA256SUMS")
  actual_sha=$(sha256sum "$stage_dir/$package" | awk '{ print $1 }')
  [[ -n "$expected_sha" && "$actual_sha" == "$expected_sha" ]] || {
    printf 'stage-blender: lean package checksum mismatch\n' >&2
    exit 1
  }
else
  (cd "$stage_dir" && sha256sum -c SHA256SUMS >/dev/null)
fi
printf '%s\n' "$stage_dir"
