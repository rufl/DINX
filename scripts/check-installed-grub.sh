#!/usr/bin/env bash
set -euo pipefail

config=${1:?usage: check-installed-grub.sh CONFIG ROOT_UUID}
root_uuid=${2:?usage: check-installed-grub.sh CONFIG ROOT_UUID}
[[ -s "$config" && "$root_uuid" =~ ^[[:xdigit:]-]+$ ]] || exit 1
# Inspect every generated Linux entry: the runner's os-prober entries must not
# turn an otherwise valid disposable-disk test into a host-dependent boot.
awk -v root="root=UUID=$root_uuid" '
  $1 == "linux" || $1 == "linuxefi" {
    found = 1
    if ($2 != "/boot/vmlinuz-linux") bad = 1
    roots = 0
    for (i = 3; i <= NF; i++) {
      if ($i ~ /^root=/) {
        roots++
        if ($i != root) bad = 1
      }
    }
    if (roots != 1) bad = 1
  }
  END { exit (!found || bad) }
' "$config" || {
  printf 'check-installed-grub: missing target kernel/root entry or foreign boot entry: %s\n' "$config" >&2
  exit 1
}
printf 'installed_grub_contract target_kernel=true target_root=true foreign_linux_entries=false\n'
