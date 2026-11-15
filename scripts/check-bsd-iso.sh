#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'check-bsd-iso: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 ]] || fail 'usage: scripts/check-bsd-iso.sh PATH_TO_ISO'
iso_path=$1
[[ -f "$iso_path" && ! -L "$iso_path" ]] || fail "ISO does not exist or is a symlink: $iso_path"

for command in awk bsdtar grep mktemp rm sha256sum wc xorriso; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

xorriso -osirrox on -indev "$iso_path" \
  -extract /etc/installerconfig "$tmp_dir/installerconfig" \
  -extract /etc/rc.local "$tmp_dir/rc.local" \
  -extract /boot/loader.conf "$tmp_dir/loader.conf" \
  -extract /usr/freebsd-dist/MANIFEST "$tmp_dir/MANIFEST" \
  -extract /usr/freebsd-dist/dinx-bsd-overlay.txz "$tmp_dir/dinx-bsd-overlay.txz" \
  >/dev/null 2>&1 || fail 'could not extract DINX-BSD payload from ISO'

boot_report=$(xorriso -indev "$iso_path" -report_el_torito plain -report_system_area plain 2>&1) \
  || fail 'could not inspect ISO boot metadata'
grep -Eq 'El Torito boot img.*BIOS' <<<"$boot_report" || fail 'BIOS El Torito entry is missing'
grep -Eq 'El Torito boot img.*UEFI' <<<"$boot_report" || fail 'UEFI El Torito entry is missing'
grep -Fq 'System area summary:' <<<"$boot_report" || fail 'hybrid system area is missing'
grep -Fq 'GPT' <<<"$boot_report" || fail 'GPT boot metadata is missing'
grep -Fq 'dinx-live' "$tmp_dir/rc.local" || fail 'ISO rc.local must boot live mode (dinx-live marker)'

shebang_count=$(grep -c '^#!' "$tmp_dir/installerconfig")
[[ "$shebang_count" == 1 ]] || fail "installerconfig must contain exactly 1 shebang for bsdinstall split, found $shebang_count"
# bsdinstall splits at the first '^#!' line: preamble variables are sourced,
# the remainder runs chrooted in the target. Validate both halves separately.
sed -n '1,/^#!/p' "$tmp_dir/installerconfig" | sed '$d' > "$tmp_dir/installerconfig.preamble"
sed -n '/^#!/,$p' "$tmp_dir/installerconfig" > "$tmp_dir/installerconfig.script"
sh -n "$tmp_dir/installerconfig.preamble" || fail 'installerconfig preamble is not valid sh'
sh -n "$tmp_dir/installerconfig.script" || fail 'installerconfig post-install script is not valid sh'
grep -Fq 'PARTITIONS=DEFAULT' "$tmp_dir/installerconfig.preamble" || fail 'installerconfig preamble must select PARTITIONS=DEFAULT before the shebang'
grep -Fq 'dinx-bsd-overlay.txz' "$tmp_dir/installerconfig.preamble" || fail 'installerconfig preamble must install the DINX-BSD overlay'
grep -Fq 'onifconsole' "$tmp_dir/installerconfig.script" || fail 'installerconfig must keep ttyu0 as onifconsole'
grep -Fq 'boot_multicons="YES"' "$tmp_dir/loader.conf" || fail 'ISO serial/video multiconsole configuration is missing'
grep -Fq 'boot_serial="YES"' "$tmp_dir/loader.conf" || fail 'ISO serial console configuration is missing'
manifest_entries=$(awk -F '\t' '$1 == "dinx-bsd-overlay.txz" { count++ } END { print count + 0 }' "$tmp_dir/MANIFEST")
[[ "$manifest_entries" == 1 ]] || fail "expected one DINX-BSD manifest entry, found $manifest_entries"
expected_sha256=$(awk -F '\t' '$1 == "dinx-bsd-overlay.txz" { print $2 }' "$tmp_dir/MANIFEST")
expected_files=$(awk -F '\t' '$1 == "dinx-bsd-overlay.txz" { print $3 }' "$tmp_dir/MANIFEST")
[[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] || fail 'overlay manifest checksum is invalid'
[[ "$expected_files" =~ ^[1-9][0-9]*$ ]] || fail 'overlay manifest file count is invalid'
actual_sha256=$(sha256sum -- "$tmp_dir/dinx-bsd-overlay.txz")
actual_sha256=${actual_sha256%% *}
[[ "$actual_sha256" == "$expected_sha256" ]] || fail 'overlay checksum does not match MANIFEST'

bsdtar -tf "$tmp_dir/dinx-bsd-overlay.txz" > "$tmp_dir/overlay.list" || fail 'overlay archive is unreadable'
actual_files=$(wc -l < "$tmp_dir/overlay.list")
actual_files=${actual_files//[[:space:]]/}
[[ "$actual_files" == "$expected_files" ]] || fail "overlay file count does not match MANIFEST: $actual_files != $expected_files"

archive_has() {
  grep -Fxq -- "$1" "$tmp_dir/overlay.list" || grep -Fxq -- "./$1" "$tmp_dir/overlay.list"
}

for required in \
  etc/dinx-release \
  etc/rc.d/dinx_firstboot \
  etc/pam.d/greetd \
  usr/local/bin/dinx-pearl-session \
  usr/local/bin/dinx-noctalia-session \
  usr/local/bin/dinx-session-select \
  usr/local/bin/dinx-live-session \
  usr/local/bin/dinx-session-set \
  usr/local/bin/dinx-wine-proton \
  usr/local/bin/dinx-first-run \
  usr/local/bin/dinx-live-persist \
  usr/local/bin/dinx-installer \
  etc/rc.d/dinx_first_run \
  etc/rc.d/dinx_live_persist \
  usr/local/libexec/dinx/session-common \
  usr/local/share/wayland-sessions/dinx-pearl.desktop \
  usr/local/share/wayland-sessions/dinx-noctalia.desktop \
  usr/local/share/themes/DINX/index.theme \
  usr/local/share/dinx/theme/DINX.json \
  usr/local/libexec/dinx-sync-session-theme \
  usr/local/etc/dinit.d/greetd \
  usr/local/etc/dinit.d/pipewire \
  usr/local/etc/dinit.d/seatd \
  usr/local/etc/greetd/config.toml \
  usr/local/etc/octapkg.conf \
  usr/local/share/dinx-bsd/distro/bsd/config/packages.txt \
  usr/local/share/dinx-bsd/distro/bsd/config/pkg-repos/dinx.conf \
  usr/local/share/dinx-bsd/distro/bsd/config/rc.d/dinx_marker \
  usr/local/share/dinx-bsd/scripts/install-dinx-bsd.sh; do
  archive_has "$required" || fail "overlay is missing $required"
done

# Any shipped .pkg must be a real FreeBSD package (root +COMPACT_MANIFEST),
# not a tarball of a staging directory.
while IFS= read -r member; do
  case "$member" in
    */data.pkg|*/packagesite.pkg|*/meta.pkg|*/meta.conf) ;;  # repo metadata
    *.pkg)
      bsdtar -xOf "$tmp_dir/dinx-bsd-overlay.txz" "$member" \
        | bsdtar -tf - 2>/dev/null | grep -Fxq '+COMPACT_MANIFEST' \
        || fail "overlay package $member is not a valid FreeBSD pkg (missing root +COMPACT_MANIFEST)"
      ;;
  esac
done < "$tmp_dir/overlay.list"

printf 'check-bsd-iso: boot=BIOS+UEFI installer=scripted overlay_sha256=%s overlay_files=%s iso=%s\n' \
  "$actual_sha256" "$actual_files" "$iso_path"
