#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 DINX Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Stage the pinned lean EuroOffice release (download + SHA256 verification).
# Prints the absolute stage directory; prints nothing and exits 0 when no pin
# exists, so builds without EuroOffice are unaffected.
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
pin_file=${EUROFFICE_PIN_FILE:-$repo_root/distro/office/eurooffice.pin}
stage_dir=${EUROFFICE_STAGE_DIR:-$repo_root/dist/office/eurooffice}
[[ -f "$pin_file" ]] || exit 0

tag=$(awk -F= '$1 == "tag" { print $2; exit }' "$pin_file")
package=$(awk -F= '$1 == "package" { print $2; exit }' "$pin_file")
squashfs=$(awk -F= '$1 == "squashfs" { print $2; exit }' "$pin_file")
[[ -n "$tag" && -n "$package" && -n "$squashfs" ]] || {
  printf 'stage-eurooffice: invalid pin: %s\n' "$pin_file" >&2
  exit 1
}

repo=${GITHUB_REPOSITORY:-rufl/DINX}
mkdir -p "$stage_dir"
for asset in "$package" "$squashfs" SHA256SUMS build-metadata.json; do
  if [[ ! -s "$stage_dir/$asset" ]]; then
    curl -fsSL "https://github.com/$repo/releases/download/$tag/$asset" -o "$stage_dir/$asset"
  fi
done
(cd "$stage_dir" && sha256sum -c SHA256SUMS >/dev/null)
printf '%s\n' "$stage_dir"
