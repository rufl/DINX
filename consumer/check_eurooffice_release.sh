#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 DINX Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Main-side EuroOffice consumer (cherry-pick to main as
# scripts/check_eurooffice_release.sh).
#
# 1. Dispatches the office-branch build workflow (it no-ops when the latest
#    upstream EuroOffice release is already packed).
# 2. When a newer eurooffice/v* DINX release exists than the local pin,
#    downloads and verifies its artifacts, stages them, and updates the pin.
#
# Emits key=value lines (GitHub Actions $GITHUB_OUTPUT when set):
#   changed, tag, version, package, squashfs
#
# Environment:
#   GITHUB_REPOSITORY      default rufl/DINX
#   EUROFFICE_PIN_FILE     default distro/office/eurooffice.pin
#   EUROFFICE_STAGE_DIR    default dist/office/eurooffice
#   EUROFFICE_SKIP_DISPATCH  1 to skip kicking the office build workflow
set -euo pipefail

repo=${GITHUB_REPOSITORY:-rufl/DINX}
pin_file=${EUROFFICE_PIN_FILE:-distro/office/eurooffice.pin}
stage_dir=${EUROFFICE_STAGE_DIR:-dist/office/eurooffice}

command -v gh >/dev/null 2>&1 || { printf 'eurooffice-consumer: gh CLI required\n' >&2; exit 1; }

emit() {
  printf '%s=%s\n' "$1" "$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; fi
}

# 1. Keep the office pipeline moving (detects new upstream releases there).
if [[ "${EUROFFICE_SKIP_DISPATCH:-0}" != 1 ]]; then
  if ! gh workflow run eurooffice.yml --repo "$repo" --ref office; then
    printf 'eurooffice-consumer: WARNING could not dispatch office pipeline\n' >&2
  fi
fi

# 2. Find the newest published lean EuroOffice release.
latest_tag=$(gh api "repos/$repo/releases?per_page=100" \
  --jq '[.[] | select(.tag_name | startswith("eurooffice/v"))][0].tag_name // ""')
if [[ -z "$latest_tag" ]]; then
  printf 'eurooffice-consumer: no eurooffice release published yet\n'
  emit changed false
  exit 0
fi
[[ "$latest_tag" =~ ^eurooffice/v([0-9]+(\.[0-9]+)+)-dinx([1-9][0-9]*)$ ]] \
  || { printf 'eurooffice-consumer: unparsable tag: %s\n' "$latest_tag" >&2; exit 1; }
version=${BASH_REMATCH[1]}
pkgrel=${BASH_REMATCH[3]}

pinned_tag=''
if [[ -f "$pin_file" ]]; then
  pinned_tag=$(awk -F= '$1 == "tag" { print $2; exit }' "$pin_file")
fi
if [[ "$pinned_tag" == "$latest_tag" ]]; then
  printf 'eurooffice-consumer: pin already at %s\n' "$latest_tag"
  emit changed false
  emit tag "$latest_tag"
  exit 0
fi

# 3. Download and verify the new release.
mkdir -p "$stage_dir"
gh release download "$latest_tag" --repo "$repo" --dir "$stage_dir" --clobber \
  --pattern '*.pkg.tar.zst' --pattern '*.squashfs' \
  --pattern SHA256SUMS --pattern build-metadata.json
(cd "$stage_dir" && sha256sum -c SHA256SUMS)

package=$(jq -r '.artifacts.package' "$stage_dir/build-metadata.json")
squashfs=$(jq -r '.artifacts.squashfs' "$stage_dir/build-metadata.json")
[[ -f "$stage_dir/$package" && -f "$stage_dir/$squashfs" ]] \
  || { printf 'eurooffice-consumer: metadata/artifact mismatch\n' >&2; exit 1; }

# 4. Update the pin.
mkdir -p "$(dirname -- "$pin_file")"
{
  printf 'tag=%s\n' "$latest_tag"
  printf 'version=%s\n' "$version"
  printf 'pkgrel=%s\n' "$pkgrel"
  printf 'package=%s\n' "$package"
  printf 'squashfs=%s\n' "$squashfs"
  printf 'sha256sums=SHA256SUMS\n'
} > "$pin_file"

printf 'eurooffice-consumer: staged %s (package=%s squashfs=%s)\n' "$latest_tag" "$package" "$squashfs"
emit changed true
emit tag "$latest_tag"
emit version "$version"
emit package "$package"
emit squashfs "$squashfs"