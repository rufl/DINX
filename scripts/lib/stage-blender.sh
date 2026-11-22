#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
pin_file=${BLENDER_PIN_FILE:-$repo_root/distro/graphics/blender/blender.pin}
stage_dir=${BLENDER_STAGE_DIR:-$repo_root/dist/graphics/blender}
[[ -f "$pin_file" ]] || exit 0

tag=$(awk -F= '$1 == "tag" { print $2; exit }' "$pin_file")
package=$(awk -F= '$1 == "package" { print $2; exit }' "$pin_file" | tr -d ' ')
full_package=$(awk -F= '$1 == "full_package" { print $2; exit }' "$pin_file" | tr -d ' ')
[[ "$tag" =~ ^blender/v[0-9]+\.[0-9]+\.[0-9]+-dinx[0-9]+$ && "$package" =~ ^blender-[^/]+\.pkg\.tar\.zst$ && "$full_package" =~ ^blender-full-[^/]+\.pkg\.tar\.zst$ ]] || {
  printf 'stage-blender: invalid pin: %s\n' "$pin_file" >&2
  exit 1
}
repo=${GITHUB_REPOSITORY:-rufl/DINX}
mkdir -p "$stage_dir"
for asset in "$package" "$full_package" SHA256SUMS build-metadata.json; do
  if [[ ! -s "$stage_dir/$asset" ]]; then
    curl_args=(-fsSL --retry 3)
    [[ -n "${GITHUB_TOKEN:-}" ]] && curl_args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    if ! curl "${curl_args[@]}" "https://github.com/$repo/releases/download/$tag/$asset" -o "$stage_dir/$asset"; then
      printf 'stage-blender: release %s is unavailable\n' "$tag" >&2
      rm -f -- "$stage_dir/$asset"
      exit 1
    fi
  fi
done
(cd "$stage_dir" && sha256sum -c SHA256SUMS >/dev/null)
printf '%s\n' "$stage_dir"
