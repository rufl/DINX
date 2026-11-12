#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Seafoam Labs
# SPDX-License-Identifier: Apache-2.0
#
# Repack a rootfs or livefs tree (non-root extract) as a SquashFS image with
# original ownerships, using fakeroot to apply the ownership exceptions that
# only root can preserve.
#
# Usage: scripts/proof-repack.sh <tree> <rootfs|livefs> <output.img> [original.img]
#
# rootfs exceptions (from the original image's non-root entries):
#   polkit rules dir, sgid tty/clock/dbus helpers, service state dirs.
# livefs exceptions: the live user home (/home/dinx) and its mail spool keep
# uid/gid 1000; the polkit rules dir keeps group polkitd.
#
# unsquashfs as a non-root user drops setuid/setgid bits at extraction time;
# when [original.img] is given, the bits are restored in the tree from the
# original image's mode table before packing.
set -euo pipefail

[[ $# -ge 3 ]] || { printf 'usage: %s <tree> <rootfs|livefs> <output.img> [original.img]\n' "$0" >&2; exit 2; }
tree=$1
kind=$2
out=$3
orig=${4:-}
[[ -d $tree ]] || { printf 'tree not found: %s\n' "$tree" >&2; exit 1; }
case "$kind" in
  rootfs|livefs) ;;
  *) printf 'kind must be rootfs or livefs\n' >&2; exit 2 ;;
esac
for command in fakeroot mksquashfs; do
  command -v "$command" >/dev/null 2>&1 || { printf 'missing required command: %s\n' "$command" >&2; exit 1; }
done
tree=$(readlink -f "$tree")
out=$(readlink -f "$out")

# Restore setuid/setgid/sticky bits that a non-root unsquashfs dropped at
# extraction time, using the original image's mode table. Runs outside
# fakeroot: the extracted files are owned by the invoking user, so chmod is
# permitted, and mksquashfs (with fakeroot ownership) preserves the bits.
if [[ -n $orig && -r $orig ]]; then
  orig=$(readlink -f "$orig")
  while read -r perms path; do
    rel=${path#squashfs-root/}
    [[ -e $tree/$rel ]] || continue
    [[ ${perms:3:1} == [sS] ]] && chmod u+s "$tree/$rel"
    [[ ${perms:6:1} == [sS] ]] && chmod g+s "$tree/$rel"
    [[ ${perms:9:1} == [tT] ]] && chmod +t "$tree/$rel"
  done < <(unsquashfs -ll "$orig" 2>/dev/null \
      | awk '$NF ~ /^squashfs-root\// && $1 ~ /[sStT]/ { print $1, $NF }')
fi

fakeroot -- sh -c '
  set -e
  tree=$1; kind=$2; out=$3; orig=$4
  chown -R 0:0 "$tree"
  if [[ $kind == rootfs ]]; then
    chown 0:102 "$tree/etc/polkit-1/rules.d"
    chown 0:11 "$tree/srv/ftp"
    chown 0:5 "$tree/usr/bin/wall" "$tree/usr/bin/write"
    chmod 2755 "$tree/usr/bin/wall" "$tree/usr/bin/write"
    chown 0:81 "$tree/usr/lib/dbus-daemon-launch-helper"
    chmod 4711 "$tree/usr/lib/dbus-daemon-launch-helper"
    chown 0:994 "$tree/usr/lib/utempter/utempter"
    chmod 2755 "$tree/usr/lib/utempter/utempter"
    chown 0:50 "$tree/var/games"
    chown 979:979 "$tree/var/lib/libuuid"
    chmod 2775 "$tree/var/lib/libuuid"
    chown -R 34:34 "$tree/var/lib/nfs/statd"
    chown 87:0 "$tree/var/lib/ntp"
    chown 32:32 "$tree/var/lib/rpcbind"
    chown -R 978:978 "$tree/var/lib/pearl-greeter" "$tree/var/cache/pearl-greeter"
    chmod 755 "$tree/var/empty/pearl-greeter"
  else
    chown -R 1000:1000 "$tree/home/dinx"
    chown 1000:1000 "$tree/var/spool/mail/dinx"
    chown 0:102 "$tree/etc/polkit-1/rules.d"
  fi
  # Single-threaded: the fakeroot stat interception is not thread-safe, and a
  # threaded mksquashfs silently drops setuid/setgid bits (sudo, su, passwd).
  mksquashfs "$tree" "$out" -noappend -comp xz -b 1048576 -no-progress \
    -processors 1
' -- "$tree" "$kind" "$out" "$orig"
