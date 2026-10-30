#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
calamares_root="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/calamares"
partition_conf="$calamares_root/modules/partition.conf"
notes_conf="$calamares_root/modules/notesqml.conf"
notes_qml="$calamares_root/branding/dinx/notesqml.qml"
mount_conf="$calamares_root/modules/mount.conf"
bootloader_conf="$calamares_root/modules/bootloader.conf"
grub_windows_conf="$repo_root/distro/iso/iso-profiles/dinx/root-overlay/etc/default/grub.d/40-dinx-windows.cfg"
settings_conf="$calamares_root/settings.conf"
packages_conf="$calamares_root/modules/packages.conf"
unpackfs_conf="$calamares_root/modules/unpackfs.conf"
profile_yaml="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
common_profile="$repo_root/distro/iso/iso-profiles/common/common.yaml"
feature_groups="$repo_root/distro/iso/iso-profiles/dinx/feature-groups.json"
workflow="$repo_root/.github/workflows/p0-iso.yml"
startup_smoke="$repo_root/scripts/smoke_calamares_startup.sh"
branding_conf="$calamares_root/branding/dinx/branding.desc"
slideshow_qml="$calamares_root/branding/dinx/show.qml"
branding_asset="$calamares_root/branding/dinx/dinx.svg"
branding_mark_asset="$calamares_root/branding/dinx/dinx-ray-mark.svg"

fail() {
  printf 'calamares_partition_contract: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -r "$1" ]] || fail "missing Calamares file: ${1#$repo_root/}"
}

require_text() {
  local needle=$1
  local path=$2
  grep -Fq -- "$needle" "$path" || fail "missing '$needle' in ${path#$repo_root/}"
}

for path in "$partition_conf" "$notes_conf" "$notes_qml" "$mount_conf" "$bootloader_conf" "$grub_windows_conf" "$settings_conf" "$packages_conf" "$unpackfs_conf" "$profile_yaml" "$common_profile" "$feature_groups" "$workflow" "$startup_smoke" "$branding_conf" "$slideshow_qml" "$branding_asset" "$branding_mark_asset"; do
  require_file "$path"
done

require_text 'recommendedSize: 1GiB' "$partition_conf"
require_text 'minimumSize: 64MiB' "$partition_conf"
require_text 'allowManualPartitioning: true' "$partition_conf"
require_text 'initialPartitioningChoice: none' "$partition_conf"
require_text '    - none' "$partition_conf"
require_text 'initialSwapChoice: none' "$partition_conf"
require_text 'availableFileSystemTypes: ["ext4", "btrfs"]' "$partition_conf"
require_text 'directory: "/"' "$partition_conf"
require_text 'allowedFilesystemTypes: ["ext4", "btrfs"]' "$partition_conf"
require_text 'mountpoint: "efi"' "$partition_conf"
require_text 'allowedFilesystemTypes: ["fat32"]' "$partition_conf"
require_text 'essentialMounts: ["live-*", "control", "ventoy"]' "$partition_conf"
require_text 'lvm:' "$partition_conf"
require_text '    enable: false' "$partition_conf"
require_text 'efiBootLoader: "grub"' "$bootloader_conf"
require_text 'efiBootloaderId: "DINX"' "$bootloader_conf"
require_text 'installEFIFallback: true' "$bootloader_conf"
require_text 'installHybridGRUB: false' "$bootloader_conf"
require_text 'GRUB_DISABLE_OS_PROBER=false' "$grub_windows_conf"
require_text '    - os-prober' "$profile_yaml"
require_text '  - linux' "$common_profile"
jq -e '.groups.optional.packages | index("ntfs-3g") != null' "$feature_groups" >/dev/null \
  || fail 'optional NTFS write package is missing from the feature manifest'
if grep -Fqx '    - ntfs-3g' "$profile_yaml"; then
  fail 'optional ntfs-3g write package is present in the base ISO profile'
fi
require_text 'Smoke-test Windows side-by-side and manual partition transactions' "$workflow"
require_text 'scripts/smoke_calamares_windows.sh' "$workflow"
require_text 'scripts/smoke_calamares_startup.sh' "$workflow"
require_text 'app_data="$work_dir/appdata"' "$startup_smoke"
require_text 'ln -s "$qml_dir" "$app_data/qml"' "$startup_smoke"
require_text 'calamares --debug --config "$app_data"' "$startup_smoke"
require_text 'slideshow: "show.qml"' "$branding_conf"
require_text 'slideshowAPI: 2' "$branding_conf"
require_text 'import calamares.slideshow 1.0' "$slideshow_qml"
require_text 'images:' "$branding_conf"
require_text 'productIcon: "dinx-ray-mark.svg"' "$branding_conf"
require_text 'productLogo: "dinx.svg"' "$branding_conf"
require_text 'productWelcome: "dinx.svg"' "$branding_conf"

require_text 'mountPoint: /' "$mount_conf"
require_text 'subvolume: ""' "$mount_conf"
if grep -Eq '^[[:space:]]+subvolume: /@' "$mount_conf"; then
  fail 'Btrfs config recreates pre-existing @ subvolumes'
fi
require_text 'filesystem: efi' "$mount_conf"
require_text 'umask=0077' "$mount_conf"

mapfile -t partition_lines < <(grep -nE '^[[:space:]]+- partition$' "$settings_conf")
[[ "${#partition_lines[@]}" -eq 2 ]] || fail 'partition module must be shown and executed exactly once'
partition_show_line=${partition_lines[0]%%:*}
partition_exec_line=${partition_lines[1]%%:*}
mapfile -t guidance_lines < <(grep -nE '^[[:space:]]+- notesqml$' "$settings_conf")
[[ "${#guidance_lines[@]}" -eq 1 ]] || fail 'install guidance page must be shown exactly once'
guidance_line=${guidance_lines[0]%%:*}
[[ "$guidance_line" -lt "$partition_show_line" ]] || fail 'install guidance must appear before partition choices'
mount_line=$(grep -nE '^[[:space:]]+- mount$' "$settings_conf" | cut -d: -f1)
unpackfs_line=$(grep -nE '^[[:space:]]+- unpackfs$' "$settings_conf" | cut -d: -f1)
fstab_line=$(grep -nE '^[[:space:]]+- fstab$' "$settings_conf" | cut -d: -f1)
bootloader_line=$(grep -nE '^[[:space:]]+- bootloader$' "$settings_conf" | cut -d: -f1)
[[ "$partition_show_line" -lt "$partition_exec_line" ]] || fail 'partition page is not before the execution module'
[[ "$partition_exec_line" -lt "$mount_line" ]] || fail 'mount runs before partition changes are committed'
[[ "$mount_line" -lt "$unpackfs_line" ]] || fail 'unpackfs runs before target mounts are ready'
[[ "$mount_line" -lt "$fstab_line" ]] || fail 'fstab runs before target mounts are ready'
[[ "$fstab_line" -lt "$bootloader_line" ]] || fail 'bootloader runs before fstab is generated'
require_text 'disable-cancel-during-exec: true' "$settings_conf"
require_text 'hide-back-and-next-during-exec: true' "$settings_conf"

require_text 'update_db: false' "$packages_conf"
require_text 'update_system: false' "$packages_conf"
require_text '  - remove:' "$packages_conf"
if grep -R -nF 'update-mirrorlist' "$calamares_root" >/dev/null; then
  fail 'Calamares configuration invokes a network mirror update'
fi
require_text 'source: "/run/artix/bootmnt/LiveOS/rootfs.img"' "$unpackfs_conf"

printf 'calamares_partition_contract=guided_choices=true no_swap_default=true safe_partition_default=true layout=true order=true efi_guard=true btrfs_existing_subvolumes=true windows_existing_esp=true manual_partitioning=true offline_packages=true ntfs3_base_rw=true ntfs3_legacy_optional=true startup_smoke=true\n'
