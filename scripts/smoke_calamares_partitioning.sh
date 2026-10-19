#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || {
    printf 'smoke-calamares-partitioning: root or sudo is required\n' >&2
    exit 1
  }
  exec sudo "$0" "$@"
fi

fail() {
  printf 'smoke-calamares-partitioning: %s\n' "$*" >&2
  exit 1
}

for command in losetup sfdisk blkid mkfs.ext4 mkfs.fat mount umount btrfs mkfs.btrfs udevadm; do
  command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done

work_dir=$(mktemp -d)
loop_devices=()
mount_points=()
cleanup() {
  set +e
  for mount_point in "${mount_points[@]}"; do
    umount "$mount_point" 2>/dev/null || true
  done
  for loop_device in "${loop_devices[@]}"; do
    losetup -d "$loop_device" 2>/dev/null || true
  done
  rm -rf "$work_dir"
}
trap cleanup EXIT

wait_for_block_device() {
  local device=$1
  for _ in {1..20}; do
    [[ -b "$device" ]] && return 0
    udevadm settle 2>/dev/null || true
    sleep 1
done
  fail "partition device did not appear: $device"
}

attach_image() {
  local image=$1
  attached_device=$(losetup --find --show --partscan "$image")
  loop_devices+=("$attached_device")
}

detach_image() {
  local device=$1
  losetup -d "$device"
  for index in "${!loop_devices[@]}"; do
    if [[ "${loop_devices[index]}" == "$device" ]]; then
      unset 'loop_devices[index]'
      break
    fi
  done
}

assert_layout_roundtrip() {
  local firmware=$1
  local image="$work_dir/dinx-${firmware}.img"
  local table_dump="$work_dir/dinx-${firmware}.sfdisk"
  local root_marker="dinx-calamares-${firmware}-root"
  local efi_marker="dinx-calamares-${firmware}-efi"
  local loop_device root_device efi_device root_mount efi_mount root_uuid efi_uuid

  truncate -s 2G "$image"
  if [[ "$firmware" == bios ]]; then
    printf 'label: dos\n, , 83, *\n' | sfdisk --wipe always "$image" >/dev/null
  else
    printf 'label: gpt\n, 1G, U\n, , L\n' | sfdisk --wipe always "$image" >/dev/null
  fi
  sfdisk --dump "$image" > "$table_dump"
  if [[ "$firmware" == bios ]]; then
    grep -Fq 'label: dos' "$table_dump" || fail 'BIOS partition table was not persisted'
  else
    grep -Fq 'label: gpt' "$table_dump" || fail 'UEFI partition table was not persisted'
    grep -Fq 'type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B' "$table_dump" || fail 'UEFI ESP type was not persisted'
  fi
  attach_image "$image"
  loop_device=$attached_device
  if [[ "$firmware" == bios ]]; then
    root_device="${loop_device}p1"
    efi_device=
  else
    efi_device="${loop_device}p1"
    root_device="${loop_device}p2"
  fi
  wait_for_block_device "$root_device"
  if [[ "$firmware" == uefi ]]; then
    wait_for_block_device "$efi_device"
    mkfs.fat -F 32 -n DINX_EFI "$efi_device" >/dev/null
  fi
  mkfs.ext4 -F -L DINX_ROOT "$root_device" >/dev/null
  root_mount="$work_dir/${firmware}-root"
  mkdir -p "$root_mount"
  mount "$root_device" "$root_mount"
  mount_points+=("$root_mount")
  root_uuid=$(blkid -s UUID -o value "$root_device")
  printf 'UUID=%s / ext4 defaults 0 1\n' "$root_uuid" > "$root_mount/fstab"
  printf '%s\n' "$root_marker" > "$root_mount/partition-smoke.marker"

  if [[ "$firmware" == uefi ]]; then
    efi_mount="$work_dir/${firmware}-efi"
    mkdir -p "$efi_mount"
    mount "$efi_device" "$efi_mount"
    mount_points+=("$efi_mount")
    efi_uuid=$(blkid -s UUID -o value "$efi_device")
    printf 'UUID=%s /boot/efi vfat umask=0077 0 2\n' "$efi_uuid" >> "$root_mount/fstab"
    printf '%s\n' "$efi_marker" > "$efi_mount/partition-smoke.marker"
    umount "$efi_mount"
    unset 'mount_points[${#mount_points[@]}-1]'
  fi
  umount "$root_mount"
  unset 'mount_points[${#mount_points[@]}-1]'
  detach_image "$loop_device"

  attach_image "$image"
  loop_device=$attached_device
  if [[ "$firmware" == bios ]]; then
    root_device="${loop_device}p1"
    efi_device=
  else
    efi_device="${loop_device}p1"
    root_device="${loop_device}p2"
  fi
  wait_for_block_device "$root_device"
  mount "$root_device" "$root_mount"
  mount_points+=("$root_mount")
  grep -Fq "$root_marker" "$root_mount/partition-smoke.marker" || fail "$firmware root filesystem transaction did not survive remount"
  grep -Fq "$root_uuid / ext4" "$root_mount/fstab" || fail "$firmware fstab transaction did not survive remount"
  umount "$root_mount"
  unset 'mount_points[${#mount_points[@]}-1]'
  if [[ "$firmware" == uefi ]]; then
    mount "$efi_device" "$efi_mount"
    grep -Fq "$efi_marker" "$efi_mount/partition-smoke.marker" || fail 'UEFI ESP transaction did not survive remount'
    umount "$efi_mount"
  fi
  detach_image "$loop_device"
  printf 'smoke-calamares-partitioning: %s table, filesystems and fstab transaction passed\n' "$firmware"
}

assert_existing_btrfs_subvolumes() {
  local image="$work_dir/dinx-btrfs.img"
  local loop_device mount_point
  truncate -s 2G "$image"
  attach_image "$image"
  loop_device=$attached_device
  mkfs.btrfs -f "$loop_device" >/dev/null
  mount_point="$work_dir/btrfs"
  mkdir -p "$mount_point"
  mount -t btrfs "$loop_device" "$mount_point"
  mount_points+=("$mount_point")
  btrfs subvolume create "$mount_point/@" >/dev/null
  btrfs subvolume create "$mount_point/@home" >/dev/null
  umount "$mount_point"
  unset 'mount_points[${#mount_points[@]}-1]'

  # DINX's mount.conf intentionally mounts the top-level volume instead of
  # recreating @ or @home. This is the safe path for an existing Btrfs layout.
  mount -t btrfs -o subvolid=5 "$loop_device" "$mount_point"
  mount_points+=("$mount_point")
  btrfs subvolume list "$mount_point" | grep -Eq '[[:space:]]path @([[:space:]]|$)' || fail 'existing Btrfs @ subvolume disappeared'
  btrfs subvolume list "$mount_point" | grep -Eq '[[:space:]]path @home([[:space:]]|$)' || fail 'existing Btrfs @home subvolume disappeared'
  printf 'dinx-calamares-btrfs-existing\n' > "$mount_point/partition-smoke.marker"
  grep -Fq 'dinx-calamares-btrfs-existing' "$mount_point/partition-smoke.marker" || fail 'Btrfs top-level transaction failed'
  umount "$mount_point"
  unset 'mount_points[${#mount_points[@]}-1]'
  detach_image "$loop_device"
  printf 'smoke-calamares-partitioning: existing Btrfs subvolumes preserved without recreation\n'
}

assert_layout_roundtrip bios
assert_layout_roundtrip uefi
assert_existing_btrfs_subvolumes
printf 'calamares_partition_smoke=bios=true uefi=true persistent_table=true btrfs_existing_subvolumes=true\n'
