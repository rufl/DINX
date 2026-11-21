#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Detect whether a new Blender package release must be generated. The
# comparison is against published DINX blender/v* releases, not the local pin.
set -euo pipefail

repo=${GITHUB_REPOSITORY:-rufl/DINX}
force=${BLENDER_FORCE:-0}
command -v gh >/dev/null 2>&1 || { printf 'detect: gh CLI required\n' >&2; exit 1; }

upstream_tag=$(gh api 'repos/blender/blender/tags?per_page=100' \
  --jq '[.[].name | select(test("^v[0-9]+(\\.[0-9]+)+$"))][0] // ""')
[[ "$upstream_tag" =~ ^v[0-9]+(\.[0-9]+)+$ ]] || {
  printf 'detect: unexpected upstream Blender tag: %s\n' "$upstream_tag" >&2
  exit 1
}
version=${BLENDER_VERSION_OVERRIDE:-${upstream_tag#v}}
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || {
  printf 'detect: invalid Blender version: %s\n' "$version" >&2
  exit 1
}

packed_tag=$(gh api "repos/$repo/releases?per_page=100" \
  --jq '[.[] | select(.tag_name | startswith("blender/v"))][0].tag_name // ""')
needs_build=false
pkgrel=1
if [[ -z "$packed_tag" ]]; then
  needs_build=true
elif [[ "$packed_tag" =~ ^blender/v([0-9]+(\.[0-9]+)+)-dinx([1-9][0-9]*)$ ]]; then
  packed_version=${BASH_REMATCH[1]}
  packed_pkgrel=${BASH_REMATCH[3]}
  if [[ "$version" != "$packed_version" ]]; then
    needs_build=true
  elif [[ "$force" == 1 ]]; then
    needs_build=true
    pkgrel=$((packed_pkgrel + 1))
  fi
else
  printf 'detect: unparsable published Blender tag: %s\n' "$packed_tag" >&2
  exit 1
fi

emit() {
  printf '%s=%s\n' "$1" "$2"
  [[ -z "${GITHUB_OUTPUT:-}" ]] || printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}
emit needs_build "$needs_build"
emit version "$version"
emit pkgrel "$pkgrel"
emit upstream_tag "$upstream_tag"
emit packed_tag "$packed_tag"
