#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
command -v curl >/dev/null || { printf 'detect: curl required\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'detect: jq required\n' >&2; exit 1; }
latest=$(curl -fsSL -H 'Accept: application/vnd.github+json' 'https://api.github.com/repos/blender/blender/tags?per_page=100' \
  | jq -r '[.[].name | select(test("^v[0-9]+(\\.[0-9]+)+$"))][0] // empty' | sed 's/^v//')
target=${BLENDER_VERSION_OVERRIDE:-$latest}
[[ "$target" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { printf 'detect: invalid upstream version: %s\n' "$target" >&2; exit 1; }
current=${BLENDER_VERSION_CURRENT:-}
if [[ -z "$current" && -f distro/graphics/blender/blender.pin ]]; then
  current=$(awk -F= '$1 == "version" { print $2; exit }' distro/graphics/blender/blender.pin)
fi
force=${BLENDER_FORCE:-0}
needs=false
[[ "$force" == 1 || "$target" != "$current" ]] && needs=true
pkgrel=1
if [[ "$needs" == true && "$target" == "$current" ]]; then pkgrel=2; fi
printf 'version=%s\n' "$target"
printf 'pkgrel=%s\n' "$pkgrel"
printf 'needs_build=%s\n' "$needs"
