#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$root/distro/packages/dinx-keyring/dinx-configure-repository"
tmp=$(mktemp -d)
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM
fail() { printf 'smoke_dinx_keyring_config: %s\n' "$1" >&2; exit 1; }

config="$tmp/pacman.conf"
printf '[options]\nArchitecture = auto\n' > "$config"
DINX_PACMAN_CONF="$config" "$helper" >/dev/null
[[ $(grep -Ec '^[[:space:]]*\[dinx\][[:space:]]*$' "$config") == 1 ]] \
  || fail 'helper did not add exactly one [dinx] stanza'
grep -Fqx '[dinx]' "$config" || fail 'DINX section is missing'
grep -Fqx 'SigLevel = Required' "$config" || fail 'required repository signature is missing'
grep -Fqx 'Include = /etc/pacman.d/dinx-mirrorlist' "$config" \
  || fail 'DINX mirrorlist include is missing'
cp -- "$config" "$tmp/first-run.conf"
DINX_PACMAN_CONF="$config" "$helper" >/dev/null
cmp -s -- "$tmp/first-run.conf" "$config" || fail 'rerunning changed the configured pacman.conf'

customized="$tmp/customized.conf"
printf '[options]\n\n[dinx]\nSigLevel = Never\nServer = https://custom.invalid/$repo/os/$arch\n' > "$customized"
cp -- "$customized" "$tmp/customized.expected"
DINX_PACMAN_CONF="$customized" "$helper" >/dev/null
cmp -s -- "$tmp/customized.expected" "$customized" \
  || fail 'preexisting customized [dinx] configuration was changed'

target="$tmp/symlink-target.conf"
link="$tmp/symlink.conf"
printf '[options]\n' > "$target"
cp -- "$target" "$tmp/symlink-target.expected"
ln -s -- "$target" "$link"
if DINX_PACMAN_CONF="$link" "$helper" >/dev/null 2>&1; then
  fail 'helper accepted a symlink pacman.conf'
fi
cmp -s -- "$tmp/symlink-target.expected" "$target" \
  || fail 'symlink target changed after rejection'

printf 'smoke_dinx_keyring_config: signed repository configuration contract passed\n'
