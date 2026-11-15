#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 DINX Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Detect whether a new EuroOffice lean package must be built.
# Compares the latest upstream Euro-Office/DesktopEditors release against the
# newest published eurooffice/v* release of this repository.
#
# Emits key=value lines (GitHub Actions $GITHUB_OUTPUT when set):
#   needs_build, version, pkgrel, upstream_tag, packed_tag, deb_url
#
# Environment:
#   GITHUB_REPOSITORY   default rufl/DINX
#   EUROFFICE_FORCE     1 to rebuild even when the version is already packed
#   EUROFFICE_VERSION   optional upstream version override (no leading v)
set -euo pipefail

repo=${GITHUB_REPOSITORY:-rufl/DINX}
upstream_repo=${EUROFFICE_UPSTREAM_REPO:-Euro-Office/DesktopEditors}
force=${EUROFFICE_FORCE:-0}

command -v gh >/dev/null 2>&1 || { printf 'detect: gh CLI required\n' >&2; exit 1; }

upstream_tag=$(gh api "repos/$upstream_repo/releases/latest" --jq '.tag_name')
[[ "$upstream_tag" =~ ^v[0-9]+(\.[0-9]+)+$ ]] || { printf 'detect: unexpected upstream tag: %s\n' "$upstream_tag" >&2; exit 1; }
version=${EUROFFICE_VERSION:-${upstream_tag#v}}

packed_tag=$(gh api "repos/$repo/releases?per_page=100" \
  --jq '[.[] | select(.tag_name | startswith("eurooffice/v"))][0].tag_name // ""')

needs_build=false
pkgrel=1
if [[ -z "$packed_tag" ]]; then
  needs_build=true
elif [[ "$packed_tag" =~ ^eurooffice/v([0-9]+(\.[0-9]+)+)-dinx([1-9][0-9]*)$ ]]; then
  packed_version=${BASH_REMATCH[1]}
  packed_pkgrel=${BASH_REMATCH[3]}
  if [[ "$version" != "$packed_version" ]]; then
    needs_build=true
  elif [[ "$force" == 1 ]]; then
    needs_build=true
    pkgrel=$((packed_pkgrel + 1))
  fi
else
  printf 'detect: unparsable packed tag: %s\n' "$packed_tag" >&2
  exit 1
fi

deb_url=''
if [[ "$needs_build" == true ]]; then
  asset_name=$(gh api "repos/$upstream_repo/releases/tags/v$version" \
    --jq '.assets[] | select(.name | test("_amd64\\.deb$")) | .name' | head -1)
  [[ -n "$asset_name" ]] || { printf 'detect: no amd64 deb asset for v%s\n' "$version" >&2; exit 1; }
  deb_url="https://github.com/$upstream_repo/releases/download/v$version/$asset_name"
fi

emit() {
  printf '%s=%s\n' "$1" "$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; fi
}
emit needs_build "$needs_build"
emit version "$version"
emit pkgrel "$pkgrel"
emit upstream_tag "v$version"
emit packed_tag "$packed_tag"
emit deb_url "$deb_url"