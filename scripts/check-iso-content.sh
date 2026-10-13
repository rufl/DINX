#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'check-iso-content: %s\n' "$*" >&2
  exit 1
}

iso_path=${1:-}
[[ -n "$iso_path" ]] || fail "usage: $0 ISO"
[[ -f "$iso_path" ]] || fail "ISO not found: $iso_path"

for command in mktemp rm xorriso unsquashfs grep; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /LiveOS/rootfs.img "$tmp_dir/rootfs.img" \
  >/dev/null

manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/rootfs.img")

required_paths=(
  etc/dinit.d/greetd
  etc/greetd/config.toml
  etc/greetd/regreet.toml
  etc/mango/dinx.conf
  etc/mango/greeter.conf
  usr/bin/mango
  usr/bin/mmsg
  usr/bin/noctalia
  usr/bin/regreet
  usr/local/libexec/dinx-regreet
  usr/share/wayland-sessions/mango.desktop
  usr/share/xdg-desktop-portal/mango-portals.conf
)

for path in "${required_paths[@]}"; do
  grep -Fq "/$path" <<<"$manifest" || fail "missing ISO path: $path"
done

grep -Fq '/usr/lib/libscenefx' <<<"$manifest" || fail 'missing Scenefx library'

printf 'ISO content check passed: MangoWM, Scenefx, Noctalia, ReGreet, greetd, and dinit payloads present.\n'
