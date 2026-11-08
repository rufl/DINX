#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$repo_root/scripts/lib/iso-content-manifest.sh"

fail() {
  printf 'smoke_iso_content_manifest: %s\n' "$*" >&2
  exit 1
}

manifest=$'drwxr-xr-x root/root 0 2026-11-08 13:34 squashfs-root/etc/calamares/\n-rw-r--r-- root/root 128 2026-11-08 13:34 squashfs-root/var/lib/pacman/local/calamares-3.4.3-6/desc\n-rwxr-xr-x root/root 1000 2026-11-08 13:34 squashfs-root/usr/bin/exiv2\nlrwxrwxrwx root/root 0 2026-11-08 13:34 squashfs-root/etc/default/grub.d/40-dinx-windows.cfg -> /etc/default/grub.d/40-dinx-windows.cfg'

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
  etc/default/grub.d/40-dinx-windows.cfg/child \
  usr/bin/ex \
  usr/bin/exi; do
  if iso_manifest_contains_path "$path" <<<"$manifest"; then
    fail "matched a different path: $path"
  fi
done

package_manifest=$'drwxr-xr-x root/root 0 2026-11-08 13:34 squashfs-root/var/lib/pacman/local/iptables-1:1.8.13-1/\n-rw-r--r-- root/root 128 2026-11-08 13:34 squashfs-root/var/lib/pacman/local/iptables-1:1.8.13-1/desc\n-rw-r--r-- root/root 128 2026-11-08 13:34 squashfs-root/var/lib/pacman/local/iptables-nft-1:1.8.13-1/desc\n-rw-r--r-- root/root 128 2026-11-08 13:34 squashfs-root/var/lib/pacman/local/portmaster-2.2.6-1/desc'
iso_manifest_contains_package iptables <<<"$package_manifest" \
  || fail 'failed to find a package metadata directory'
iso_manifest_contains_package portmaster <<<"$package_manifest" \
  || fail 'failed to find a retired package metadata directory'
iptables_nft_manifest=$(grep -F 'iptables-nft-' <<<"$package_manifest")
if iso_manifest_contains_package iptables <<<"$iptables_nft_manifest"; then
  fail 'matched a package with a shared name prefix'
fi

printf 'iso_content_manifest_smoke exact_paths=true package_metadata=true exact_package_boundary=true symlink_annotation=true near_matches_rejected=true\n'
