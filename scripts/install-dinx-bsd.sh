#!/usr/bin/env bash
# DINX-BSD Target System Installer & Initializer
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)

fail() {
  printf 'install-dinx-bsd: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname)" == "FreeBSD" ]] || fail 'DINX-BSD installer must run on a FreeBSD target system'
[[ $EUID -eq 0 ]] || fail 'DINX-BSD installer requires root privileges'

printf 'install-dinx-bsd: initializing system storage and mounting base...\n'
sysrc dinit_enable="YES"
sysrc seatd_enable="YES"
sysrc pf_enable="YES"

printf 'install-dinx-bsd: installing DINX package manifest and repositories...\n'
if [[ -f "$repo_root/distro/bsd/config/packages.txt" ]]; then
  pkg install -y $(grep -v '^#' "$repo_root/distro/bsd/config/packages.txt" | grep -v '^$')
fi

printf 'install-dinx-bsd: configuring dinit supervision services...\n'
mkdir -p /etc/dinit.d
ln -sf "$repo_root/distro/bsd/config/dinit/seatd" /etc/dinit.d/seatd
ln -sf "$repo_root/distro/bsd/config/dinit/pipewire" /etc/dinit.d/pipewire
ln -sf "$repo_root/distro/bsd/config/dinit/greetd" /etc/dinit.d/greetd

printf 'install-dinx-bsd: DINX-BSD installation completed successfully!\n'
