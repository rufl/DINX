#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
common="$repo_root/distro/iso/iso-profiles/common/common.yaml"
groups="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
mimeapps="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/xdg/mimeapps.list"
iso_check="$repo_root/scripts/check-iso-content.sh"
workflow="$repo_root/.github/workflows/p0-iso.yml"
calamares_check="$repo_root/scripts/check_calamares_partitioning.sh"
pori_dir="$repo_root/distro/packages/pori"
phyto_dir="$repo_root/distro/packages/phyto"

fail() {
  printf 'pori_phyto_contract: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -r "$1" ]] || fail "missing file: ${1#$repo_root/}"
}

for path in \
  "$profile" "$common" "$groups" "$mimeapps" "$iso_check" "$workflow" "$calamares_check" \
  "$pori_dir/PKGBUILD" "$pori_dir/source.env" \
  "$pori_dir/units-dinit.zig" "$pori_dir/privops-dinit.zig" \
  "$pori_dir/watch-dinit.zig" "$pori_dir/pori-dinit.patch" \
  "$pori_dir/pori-mount-service" \
  "$repo_root/scripts/smoke_pori_zig.sh" \
  "$phyto_dir/PKGBUILD" "$phyto_dir/source.env"; do
  require_file "$path"
done

for package in file-roller gparted phyto pori; do
  grep -Fqx "    - $package" "$profile" || fail "profile is missing $package"
done
jq -e '.groups.desktop.packages | index("phyto") != null and index("pori") != null' "$groups" >/dev/null \
  || fail 'desktop feature group does not contain both Phyto and Pori'
jq -e '.groups.optional.packages | index("ntfs-3g") != null' "$groups" >/dev/null \
  || fail 'optional feature group is missing ntfs-3g'
grep -Fqx '  - linux' "$common" || fail 'common profile no longer installs the kernel ntfs3 driver'
if grep -Fqx '    - ntfs-3g' "$profile"; then
  fail 'ntfs-3g is still in the base ISO profile'
fi

for removed in gvfs gvfs-gphoto2 gvfs-mtp gvfs-smb partitionmanager thunar thunar-archive-plugin thunar-volman tumbler; do
  if grep -Fqx "    - $removed" "$profile"; then
    fail "removed storage package remains in profile: $removed"
  fi
  if jq -e --arg package "$removed" 'any(.groups[].packages[]; . == $package)' "$groups" >/dev/null; then
    fail "removed storage package remains in feature groups: $removed"
  fi
done
if grep -Eiq 'labwc|noctalia' "$profile" "$groups" "$mimeapps"; then
  fail 'retired Labwc or Noctalia integration remains in the storage contract'
fi

for path in "$pori_dir/units-dinit.zig" "$pori_dir/privops-dinit.zig" "$pori_dir/watch-dinit.zig" "$pori_dir/PKGBUILD" "$pori_dir/pori-mount-service"; do
  if grep -Eiq 'systemd|systemctl|/etc/systemd' "$path"; then
    fail "Pori dinit implementation contains systemd references: ${path#$repo_root/}"
  fi
done
for required in '/etc/dinit.d' 'dinitctl --system' 'type = process' 'pori-mount-service' 'restart = true' 'restart-delay = 5' 'restart-limit-count = 0' 'ntfs3'; do
  grep -Fq -- "$required" "$pori_dir/privops-dinit.zig" || fail "Pori dinit implementation is missing: $required"
done
grep -Fq 'org.freedesktop.UDisks2' "$pori_dir/watch-dinit.zig" || fail 'Pori no longer watches UDisks2'
grep -Fq 'Pori-What:' "$pori_dir/units-dinit.zig" || fail 'Pori mount metadata parser is missing'
grep -Fq 'Pori-Where:' "$pori_dir/units-dinit.zig" || fail 'Pori mount target metadata parser is missing'
grep -Fq 'dinit mount service' "$pori_dir/pori-dinit.patch" || fail 'Pori UI does not describe dinit mount services'

grep -Fqx 'inode/directory=org.aqueous.Phyto.desktop;' "$mimeapps" || fail 'Phyto is not the default directory handler'

for required in \
  '  usr/bin/phyto' \
  '  usr/bin/pori' \
  '  usr/local/libexec/pori-mount-service' \
  '  usr/bin/file-roller' \
  '  usr/bin/gparted' \
  '  usr/share/applications/com.pori.app.desktop' \
  '  usr/share/applications/org.aqueous.Phyto.desktop' \
  '  usr/share/applications/org.gnome.FileRoller.desktop' \
  '  usr/share/applications/gparted.desktop'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done
grep -Fq 'build_package phyto' "$workflow" || fail 'workflow does not build Phyto'
grep -Fq 'build_package pori' "$workflow" || fail 'workflow does not build Pori'
grep -Fq '"${ZIG:-zig}" build' "$pori_dir/PKGBUILD" || fail 'Pori package does not honor the selected Zig toolchain'
grep -Fq '"${ZIG:-zig}" build' "$phyto_dir/PKGBUILD" || fail 'Phyto package does not honor the selected Zig toolchain'
grep -Fq 'zig_version=0.17.0' "$workflow" || fail 'workflow does not pin Zig 0.17 for Pori and Phyto'
grep -Fq 'zig_sha256=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026' "$workflow" \
  || fail 'workflow does not verify the Zig 0.17 archive'
grep -Fq 'ZIG=/tmp/zig-x86_64-linux-${zig_version}/zig' "$workflow" \
  || fail 'workflow does not pass Zig 0.17 to Pori and Phyto'
grep -Fq 'scripts/smoke_pori_zig.sh' "$workflow" || fail 'workflow does not run the Pori Zig source smoke'
grep -Fq 'scripts/check_pori_phyto.sh' "$workflow" || fail 'workflow does not run the Pori/Phyto contract'
grep -Fq 'ntfs3\.ko' "$iso_check" || fail 'ISO contract does not require the kernel ntfs3 module'
grep -Fq '/usr/bin/ntfs-3g' "$iso_check" || fail 'ISO contract does not reject the optional ntfs-3g package'
grep -Fq 'ntfs-3g' "$calamares_check" || fail 'Calamares contract does not document optional NTFS write support'

printf 'pori_phyto_contract pori=true phyto=true dinit=true udisks2_backend=true archive_tool=file-roller partition_editor=gparted old_storage_stack=false ntfs3_live_rw=true ntfs3_legacy_optional=true zig_tests=true\n'
