#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)

fail() {
  printf 'build-bsd-iso: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/build-bsd-iso.sh [--validate]

Builds a bootable amd64 DINX-BSD installer ISO from the checksum-pinned
FreeBSD disc1 image. --validate performs an unattended QEMU installation
and waits for the installed DINX-BSD first-boot marker.
EOF
}

validate=false
while (($# > 0)); do
  case "$1" in
    --validate)
      validate=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

for command in bsdtar cp find install mktemp mv rm sha256sum touch wc xorriso; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

freebsd_version=${DINX_BSD_FREEBSD_VERSION:-15.1}
source_iso_sha256=${DINX_BSD_SOURCE_SHA256:-fa27646f05a1440fd26ffbb85e06a50bc86e128242a4e9cb7bb3ea76e1aa5fd9}
source_iso_name="FreeBSD-${freebsd_version}-RELEASE-amd64-disc1.iso"
source_iso_url=${DINX_BSD_SOURCE_URL:-"https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/${freebsd_version}/${source_iso_name}"}
[[ "$freebsd_version" =~ ^[0-9]+\.[0-9]+$ ]] || fail 'DINX_BSD_FREEBSD_VERSION must be MAJOR.MINOR'
[[ "$source_iso_sha256" =~ ^[0-9a-f]{64}$ ]] || fail 'DINX_BSD_SOURCE_SHA256 must be 64 lowercase hexadecimal characters'

output_dir=${DINX_BSD_OUTPUT_DIR:-"$repo_root/dist/bsd-iso"}
cache_dir=${DINX_BSD_CACHE_DIR:-"$repo_root/dist/bsd-cache"}
output_iso="$output_dir/DINX-BSD-${freebsd_version}-RELEASE-amd64.iso"
output_checksum="$output_iso.sha256"
metadata_path="$output_dir/build-metadata.txt"
qemu_log="$output_dir/dinx-bsd-install.qemu.log"
mkdir -p -- "$output_dir" "$cache_dir"

if [[ -n ${DINX_BSD_SOURCE_ISO:-} ]]; then
  source_iso=$DINX_BSD_SOURCE_ISO
  [[ -f "$source_iso" && ! -L "$source_iso" ]] || fail "source ISO does not exist or is a symlink: $source_iso"
  actual_source_sha256=$(sha256sum -- "$source_iso")
  actual_source_sha256=${actual_source_sha256%% *}
  [[ "$actual_source_sha256" == "$source_iso_sha256" ]] \
    || fail "source ISO checksum mismatch: expected $source_iso_sha256, got $actual_source_sha256"
else
  source_iso="$cache_dir/$source_iso_name"
  "$script_dir/cache-verified-download.sh" "$source_iso" "$source_iso_url" "$source_iso_sha256"
fi

source_commit=unknown
source_date_epoch=${SOURCE_DATE_EPOCH:-}
if command -v git >/dev/null 2>&1 && git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  source_commit=$(git -C "$repo_root" rev-parse HEAD)
  if [[ -z "$source_date_epoch" ]]; then
    source_date_epoch=$(git -C "$repo_root" show -s --format=%ct HEAD)
  fi
fi
source_date_epoch=${source_date_epoch:-0}
[[ "$source_date_epoch" =~ ^[0-9]+$ ]] || fail 'SOURCE_DATE_EPOCH must be a non-negative integer'

tmp_dir=$(mktemp -d)
temporary_iso="$output_dir/.DINX-BSD-${freebsd_version}-RELEASE-amd64.iso.$$.tmp"
cleanup() {
  rm -rf -- "$tmp_dir"
  rm -f -- "$temporary_iso"
}
trap cleanup EXIT

overlay_root="$tmp_dir/overlay-root"
overlay_archive="$tmp_dir/dinx-bsd-overlay.txz"
installerconfig="$repo_root/distro/bsd/iso/installerconfig"
manifest="$tmp_dir/MANIFEST"
loader_conf="$tmp_dir/loader.conf"

[[ -r "$installerconfig" ]] || fail "missing installer configuration: $installerconfig"
install -d \
  "$overlay_root/etc" \
  "$overlay_root/usr/local/etc/dinit.d" \
  "$overlay_root/usr/local/share/dinx-bsd/distro/bsd" \
  "$overlay_root/usr/local/share/dinx-bsd/scripts"
cp -a "$repo_root/distro/bsd/." "$overlay_root/usr/local/share/dinx-bsd/distro/bsd/"
# Real native packages built in the FreeBSD build VM (dist/, git-ignored).
if [ -d "$repo_root/dist/bsd/ports/pkg/repo" ]; then
  install -d "$overlay_root/usr/local/share/dinx-bsd/distro/bsd/ports/pkg/repo"
  cp -a "$repo_root/dist/bsd/ports/pkg/repo/." \
    "$overlay_root/usr/local/share/dinx-bsd/distro/bsd/ports/pkg/repo/"
fi
# DINX themes (GTK3/4, Pearl palette, qt6ct seed) from the themes branch.
if [ -d "$repo_root/distro/bsd/config/theme-overlay" ]; then
  cp -a "$repo_root/distro/bsd/config/theme-overlay/." "$overlay_root/"
fi
install -m 0755 "$repo_root/scripts/install-dinx-bsd.sh" \
  "$overlay_root/usr/local/share/dinx-bsd/scripts/install-dinx-bsd.sh"
install -m 0644 "$repo_root/LICENSE" "$overlay_root/usr/local/share/dinx-bsd/LICENSE"
install -m 0644 "$repo_root/distro/bsd/config/octapkg.conf" \
  "$overlay_root/usr/local/etc/octapkg.conf"
for unit in greetd pipewire seatd; do
  install -m 0644 "$repo_root/distro/bsd/config/dinit/$unit" \
    "$overlay_root/usr/local/etc/dinit.d/$unit"
done
if [[ -f "$repo_root/distro/bsd/config/greetd.toml" ]]; then
  install -d "$overlay_root/usr/local/etc/greetd"
  install -m 0644 "$repo_root/distro/bsd/config/greetd.toml" \
    "$overlay_root/usr/local/etc/greetd/config.toml"
fi
install -d "$overlay_root/etc/rc.d" "$overlay_root/usr/local/bin"
for unit in dinx_firstboot dinx_greetd dinx_first_run dinx_live_persist; do
  install -m 0555 "$repo_root/distro/bsd/config/rc.d/$unit" \
    "$overlay_root/etc/rc.d/$unit"
done
install -d "$overlay_root/usr/local/libexec/dinx" \
  "$overlay_root/usr/local/share/wayland-sessions"
for s in dinx-pearl-session dinx-noctalia-session dinx-session-select dinx-session-set dinx-wine-proton dinx-first-run dinx-live-persist dinx-installer; do
  install -m 0755 "$repo_root/distro/bsd/config/bin/$s" \
    "$overlay_root/usr/local/bin/$s"
done
install -m 0644 "$repo_root/distro/bsd/config/bin/dinx-session-common" \
  "$overlay_root/usr/local/libexec/dinx/session-common"
for d in dinx-pearl dinx-noctalia; do
  install -m 0644 "$repo_root/distro/bsd/config/wayland-sessions/$d.desktop" \
    "$overlay_root/usr/local/share/wayland-sessions/$d.desktop"
done
{
  printf 'DINX_BSD_RELEASE=foundation\n'
  printf 'FREEBSD_RELEASE=%s-RELEASE\n' "$freebsd_version"
  printf 'SOURCE_COMMIT=%s\n' "$source_commit"
} > "$overlay_root/etc/dinx-release"

find "$overlay_root" -exec touch -h -d "@$source_date_epoch" {} +
bsdtar --format pax --uid 0 --gid 0 --uname root --gname wheel \
  --mtime "@$source_date_epoch" -cJf "$overlay_archive" -C "$overlay_root" .
overlay_sha256=$(sha256sum -- "$overlay_archive")
overlay_sha256=${overlay_sha256%% *}
overlay_files=$(bsdtar -tf "$overlay_archive" | wc -l)
overlay_files=${overlay_files//[[:space:]]/}
[[ "$overlay_files" =~ ^[1-9][0-9]*$ ]] || fail 'DINX-BSD overlay is empty'

xorriso -osirrox on -indev "$source_iso" \
  -extract /usr/freebsd-dist/MANIFEST "$manifest" \
  -extract /boot/loader.conf "$loader_conf" \
  >/dev/null 2>&1 || fail 'could not extract FreeBSD ISO metadata'
grep -q '^dinx-bsd-overlay\.txz[[:space:]]' "$manifest" \
  && fail 'source ISO unexpectedly already contains a DINX-BSD overlay'
printf 'dinx-bsd-overlay.txz\t%s\t%s\tdinx_bsd\t"DINX-BSD base overlay"\ton\n' \
  "$overlay_sha256" "$overlay_files" >> "$manifest"
for setting in \
  'boot_multicons="YES"' \
  'boot_serial="YES"' \
  'comconsole_speed="115200"'; do
  grep -Fqx "$setting" "$loader_conf" || printf '%s\n' "$setting" >> "$loader_conf"
done

# Embed base/kernel distribution sets so the scripted install never prompts
# for a mirror (15.x disc1 ships them only as pkgbase packages).
dist_sets_url="https://download.freebsd.org/releases/amd64/amd64/${freebsd_version}-RELEASE"
for set in base kernel; do
  set_sha=$(awk -F '\t' -v s="${set}.txz" '$1 == s { print $2 }' "$manifest")
  [[ "$set_sha" =~ ^[0-9a-f]{64}$ ]] || fail "MANIFEST lacks ${set}.txz checksum"
  "$script_dir/cache-verified-download.sh" "$cache_dir/${set}.txz" \
    "$dist_sets_url/${set}.txz" "$set_sha"
done

rm -f -- "$temporary_iso"
xorriso -abort_on FAILURE -return_with SORRY 32 \
  -indev "$source_iso" \
  -outdev "$temporary_iso" \
  -overwrite on \
  -map "$installerconfig" /etc/installerconfig \
  -map "$repo_root/distro/bsd/iso/rc.local.live" /etc/rc.local \
  -map "$loader_conf" /boot/loader.conf \
  -map "$manifest" /usr/freebsd-dist/MANIFEST \
  -map "$overlay_archive" /usr/freebsd-dist/dinx-bsd-overlay.txz \
  -map "$cache_dir/base.txz" /usr/freebsd-dist/base.txz \
  -map "$cache_dir/kernel.txz" /usr/freebsd-dist/kernel.txz \
  -boot_image any replay \
  -end

"$script_dir/check-bsd-iso.sh" "$temporary_iso"
chmod 0644 "$temporary_iso"
mv -f -- "$temporary_iso" "$output_iso"
(cd "$output_dir" && sha256sum "$(basename -- "$output_iso")" > "$(basename -- "$output_checksum")")
(cd "$output_dir" && sha256sum --check --status "$(basename -- "$output_checksum")") \
  || fail 'generated ISO checksum verification failed'

qemu_validation=skipped
if [[ "$validate" == true ]]; then
  command -v python3 >/dev/null 2>&1 || fail 'required command not found: python3'
  python3 "$script_dir/build-bsd-iso-unattended.py" \
    --timeout "${DINX_BSD_QEMU_TIMEOUT:-1200}" \
    --accel "${DINX_BSD_QEMU_ACCEL:-auto}" \
    --log "$qemu_log" \
    "$output_iso"
  qemu_validation=passed
fi

output_sha256=$(sha256sum -- "$output_iso")
output_sha256=${output_sha256%% *}
output_sha512=$(sha512sum -- "$output_iso")
output_sha512=${output_sha512%% *}
output_bytes=$(stat -c %s "$output_iso")
{
  printf 'schema=dinx-bsd-iso/v1\n'
  printf 'source_commit=%s\n' "$source_commit"
  printf 'source_date_epoch=%s\n' "$source_date_epoch"
  printf 'freebsd_release=%s-RELEASE\n' "$freebsd_version"
  printf 'source_iso_url=%s\n' "$source_iso_url"
  printf 'source_iso_sha256=%s\n' "$source_iso_sha256"
  printf 'overlay_sha256=%s\n' "$overlay_sha256"
  printf 'overlay_files=%s\n' "$overlay_files"
  printf 'iso_name=%s\n' "$(basename -- "$output_iso")"
  printf 'iso_bytes=%s\n' "$output_bytes"
  printf 'iso_sha256=%s\n' "$output_sha256"
  printf 'iso_sha512=%s\n' "$output_sha512"
  printf 'qemu_install_validation=%s\n' "$qemu_validation"
} > "$metadata_path"

printf 'build-bsd-iso: artifact=%s sha256=%s qemu_install=%s\n' \
  "$output_iso" "$output_sha256" "$qemu_validation"
