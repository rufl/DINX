#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

repo=${GITHUB_REPOSITORY:-rufl/DINX}
pin_file=${BLENDER_PIN_FILE:-distro/graphics/blender/blender.pin}
stage_dir=${BLENDER_STAGE_DIR:-dist/graphics/blender}
command -v gh >/dev/null 2>&1 || { printf 'blender-consumer: gh CLI required\n' >&2; exit 1; }
emit() { printf '%s=%s\n' "$1" "$2"; [[ -z "${GITHUB_OUTPUT:-}" ]] || printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; }

if [[ "${BLENDER_SKIP_DISPATCH:-0}" != 1 ]]; then
  before=$(gh run list --workflow blender.yml --repo "$repo" --branch blender --limit 1 --json databaseId --jq '.[0].databaseId // "0"')
  if gh workflow run blender.yml --repo "$repo" --ref blender; then
    new_run=''
    for _ in $(seq 1 12); do
      sleep 5
      candidate=$(gh run list --workflow blender.yml --repo "$repo" --branch blender --limit 1 --json databaseId --jq '.[0].databaseId // "0"')
      if [[ "$candidate" != "$before" ]]; then new_run=$candidate; break; fi
    done
    if [[ -n "$new_run" ]]; then
      deadline=$(( $(date +%s) + 7200 ))
      while :; do
        status=$(gh run view "$new_run" --repo "$repo" --json status,conclusion --jq '[.status,.conclusion]|@tsv')
        case "$status" in
          completed$'\tsuccess') break ;;
          completed*) printf 'blender-consumer: build run ended: %s\n' "$status" >&2; break ;;
        esac
        (( $(date +%s) < deadline )) || break
        sleep 30
      done
    fi
  else
    printf 'blender-consumer: warning: could not dispatch blender pipeline\n' >&2
  fi
fi

latest_tag=$(gh api "repos/$repo/releases?per_page=100" --jq '[.[] | select(.tag_name | startswith("blender/v"))][0].tag_name // ""')
[[ -n "$latest_tag" ]] || { emit changed false; exit 0; }
[[ "$latest_tag" =~ ^blender/v([0-9]+(\.[0-9]+)+)-dinx([1-9][0-9]*)$ ]] || {
  printf 'blender-consumer: unparsable tag: %s\n' "$latest_tag" >&2; exit 1;
}
version=${BASH_REMATCH[1]}; pkgrel=${BASH_REMATCH[3]}
pinned_tag=''
[[ -f "$pin_file" ]] && pinned_tag=$(awk -F= '$1 == "tag" { print $2; exit }' "$pin_file")
if [[ "$pinned_tag" == "$latest_tag" ]]; then
  emit changed false; emit tag "$latest_tag"; exit 0
fi
mkdir -p "$stage_dir"
gh release download "$latest_tag" --repo "$repo" --dir "$stage_dir" --clobber \
  --pattern '*.pkg.tar.zst' --pattern SHA256SUMS --pattern build-metadata.json
(cd "$stage_dir" && sha256sum -c SHA256SUMS)
package=$(jq -r '.artifacts.lean_package' "$stage_dir/build-metadata.json")
full_package=$(jq -r '.artifacts.full_package' "$stage_dir/build-metadata.json")
[[ -f "$stage_dir/$package" && -f "$stage_dir/$full_package" ]] || {
  printf 'blender-consumer: metadata/artifact mismatch\n' >&2; exit 1;
}
mkdir -p "$(dirname -- "$pin_file")"
{
  printf 'tag=%s\n' "$latest_tag"
  printf 'version=%s\n' "$version"
  printf 'pkgrel=%s\n' "$pkgrel"
  printf 'package=%s\n' "$package"
  printf 'full_package=%s\n' "$full_package"
  printf 'sha256sums=SHA256SUMS\n'
} > "$pin_file"
emit changed true; emit tag "$latest_tag"; emit version "$version"; emit pkgrel "$pkgrel"; emit package "$package"; emit full_package "$full_package"
