#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$repo_root/scripts/lib/iso-content-manifest.sh"

fail() {
  printf 'smoke_iso_content_manifest: %s\n' "$*" >&2
  exit 1
}

manifest=$'drwxr-xr-x root/root 0 2026-11-08 13:34 squashfs-root/etc/calamares/\n-rw-r--r-- root/root 128 2026-11-08 13:34 squashfs-root/var/lib/pacman/local/calamares-3.4.3-6/desc\nlrwxrwxrwx root/root 0 2026-11-08 13:34 squashfs-root/etc/default/grub.d/40-dinx-windows.cfg -> /etc/default/grub.d/40-dinx-windows.cfg'

for path in \
  etc/calamares \
  var/lib/pacman/local/calamares-3.4.3-6/desc \
  etc/default/grub.d/40-dinx-windows.cfg; do
  iso_manifest_contains_path "$path" <<<"$manifest" \
    || fail "failed to match unsquashfs listing path: $path"
done

for path in \
  var/lib/pacman/local/calamares-3.4.3-60/desc \
  var/lib/pacman/local/calamares-3.4.3-6/files \
  etc/default/grub.d/40-dinx-windows.cfg/child; do
  if iso_manifest_contains_path "$path" <<<"$manifest"; then
    fail "matched a different path: $path"
  fi
done

printf 'iso_content_manifest_smoke exact_paths=true metadata_prefix=true symlink_annotation=true near_matches_rejected=true\n'
