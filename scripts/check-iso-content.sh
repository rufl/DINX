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

xorriso -osirrox on \
  -indev "$iso_path" \
  -extract /LiveOS/livefs.img "$tmp_dir/livefs.img" \
  >/dev/null

manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/rootfs.img")
livefs_manifest=$(unsquashfs -no-xattrs -no-progress -lls "$tmp_dir/livefs.img")

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

livefs_required_paths=(
  etc/artools/live.conf
  etc/dinit.d/boot.d/NetworkManager
  etc/dinit.d/boot.d/artix-live
  etc/dinit.d/boot.d/greetd
  etc/dinit.d/boot.d/logind
  etc/dinit.d/boot.d/metalog
  etc/dinit.d/boot.d/pacman-init
  etc/dinit.d/boot.d/userspawn
)

for path in "${livefs_required_paths[@]}"; do
  grep -Fq "/$path" <<<"$livefs_manifest" || fail "missing livefs path: $path"
done

live_config=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/artools/live.conf)
grep -Fq 'AUTOLOGIN=false' <<<"$live_config" || fail 'live session autologin is not disabled'
grep -Fq 'LIVEUSER=dinx' <<<"$live_config" || fail 'live session user is not dinx'

live_passwd=$(unsquashfs -no-xattrs -no-progress -cat "$tmp_dir/livefs.img" etc/passwd)
grep -Eq '^dinx:' <<<"$live_passwd" || fail 'live session user dinx is missing'

printf 'ISO content check passed: MangoWM, Scenefx, Noctalia, ReGreet, greetd, and dinit payloads present.\n'
